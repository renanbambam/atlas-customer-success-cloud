@IsTest
private class SubscriptionTriggerTest {
    private static final Integer BULK_SIZE = 200;

    @TestSetup
    static void setup() {
        TestDataFactory.createAccounts(BULK_SIZE);
    }

    @IsTest
    static void activationCreatesOneRenewalOpportunityPerSubscriptionInBulk() {
        List<Account> accounts = [SELECT Id FROM Account];
        List<Subscription__c> subscriptions = TestDataFactory.createSubscriptions(accounts, 'Draft');

        for (Subscription__c subscription : subscriptions) {
            subscription.Status__c = 'Active';
        }
        Test.startTest();
        update subscriptions;
        Test.stopTest();

        List<Opportunity> renewals = [
            SELECT Subscription__c, CloseDate, RecordType.DeveloperName
            FROM Opportunity
            WHERE Subscription__c IN :subscriptions
        ];
        System.assertEquals(BULK_SIZE, renewals.size(), 'One renewal per activated subscription');
        System.assertEquals('Renewal', renewals[0].RecordType.DeveloperName);
    }

    @IsTest
    static void activationIsIdempotentOnRepeatedSaves() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        List<Subscription__c> subscriptions = TestDataFactory.createSubscriptions(accounts, 'Draft');
        subscriptions[0].Status__c = 'Active';
        update subscriptions;

        // A no-op edit on an already-active subscription must not duplicate the pipeline.
        subscriptions[0].Auto_Renew__c = true;
        update subscriptions;

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Opportunity WHERE Subscription__c = :subscriptions[0].Id],
            'Renewal opportunity must not be duplicated'
        );
    }

    @IsTest
    static void renewalDateMoveRealignsOpenRenewalOpportunity() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        List<Subscription__c> subscriptions = TestDataFactory.createSubscriptions(accounts, 'Draft');
        subscriptions[0].Status__c = 'Active';
        update subscriptions;

        Date movedDate = Date.today().addMonths(9);
        subscriptions[0].Renewal_Date__c = movedDate;
        update subscriptions;

        Opportunity renewal = [
            SELECT CloseDate
            FROM Opportunity
            WHERE Subscription__c = :subscriptions[0].Id
        ];
        System.assertEquals(movedDate, renewal.CloseDate, 'Close date must follow the renewal date');
    }

    @IsTest
    static void churnClosesOpenRenewalAsLost() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        List<Subscription__c> subscriptions = TestDataFactory.createSubscriptions(accounts, 'Draft');
        subscriptions[0].Status__c = 'Active';
        update subscriptions;

        subscriptions[0].Status__c = 'Churned';
        update subscriptions;

        Opportunity renewal = [
            SELECT StageName, IsClosed
            FROM Opportunity
            WHERE Subscription__c = :subscriptions[0].Id
        ];
        System.assertEquals('Closed Lost', renewal.StageName);
        System.assert(renewal.IsClosed);
    }

    @IsTest
    static void invalidTransitionIsRejectedWithoutBlockingValidRows() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 2];
        List<Subscription__c> subscriptions = TestDataFactory.createSubscriptions(accounts, 'Draft');
        subscriptions[0].Status__c = 'Active';
        update subscriptions[0];
        subscriptions[0].Status__c = 'Draft'; // Active -> Draft is not a legal transition
        subscriptions[1].Status__c = 'Active';

        List<Database.SaveResult> results = Database.update(subscriptions, false);

        System.assert(!results[0].isSuccess(), 'Illegal transition must fail');
        System.assert(
            results[0].getErrors()[0].getMessage().contains('Invalid status transition'),
            'Error should explain the transition rule'
        );
        System.assert(results[1].isSuccess(), 'The valid row must save');
    }

    @IsTest
    static void activatingWithoutRenewalDateDefaultsToEndDate() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        Subscription__c subscription = new Subscription__c(
            Account__c = accounts[0].Id,
            Status__c = 'Active',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addYears(1)
        );
        insert subscription;

        subscription = [SELECT Renewal_Date__c, End_Date__c FROM Subscription__c WHERE Id = :subscription.Id];
        System.assertEquals(subscription.End_Date__c, subscription.Renewal_Date__c);
    }

    @IsTest
    static void bypassSuppressesAutomationForMigrations() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        TriggerHandler.bypass('SubscriptionTriggerHandler');
        try {
            List<Subscription__c> subscriptions = TestDataFactory.createSubscriptions(accounts, 'Draft');
            subscriptions[0].Status__c = 'Active';
            // Bypass suppresses defaulting too — a migration supplies complete rows.
            subscriptions[0].Renewal_Date__c = Date.today().addMonths(6);
            update subscriptions;
            System.assertEquals(
                0,
                [SELECT COUNT() FROM Opportunity WHERE Subscription__c = :subscriptions[0].Id],
                'Bypassed handler must not create pipeline records'
            );
        } finally {
            TriggerHandler.clearBypass('SubscriptionTriggerHandler');
        }
        System.assert(!TriggerHandler.isBypassed('SubscriptionTriggerHandler'));
    }
}
