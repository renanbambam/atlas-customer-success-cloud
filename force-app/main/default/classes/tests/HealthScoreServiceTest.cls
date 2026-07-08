@IsTest
private class HealthScoreServiceTest {
    @TestSetup
    static void setup() {
        List<Account> accounts = TestDataFactory.createAccounts(2);
        TestDataFactory.createSubscriptions(accounts, 'Active');
    }

    @IsTest
    static void healthyAccountScoresLowRiskWithDimensionBreakdown() {
        Account account = [SELECT Id FROM Account ORDER BY Name LIMIT 1];
        account.License_Utilization__c = 80;
        update account;
        TestDataFactory.createNpsResponses(account, new List<Integer>{ 10, 10, 9 });

        Test.startTest();
        new HealthScoreService().calculate(new Set<Id>{ account.Id }, System.AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        account = [
            SELECT Health_Score__c, Churn_Risk__c, Health_Trend__c, Health_Score_Updated__c
            FROM Account
            WHERE Id = :account.Id
        ];
        System.assertNotEquals(null, account.Health_Score__c);
        System.assertEquals(
            'Low',
            account.Churn_Risk__c,
            'High adoption + all promoters + no cases = Low risk'
        );
        System.assertEquals(
            'Stable',
            account.Health_Trend__c,
            'First scoring has no baseline to trend against'
        );
        System.assertNotEquals(null, account.Health_Score_Updated__c);

        Health_Score_Snapshot__c snapshot = [
            SELECT
                Score__c,
                Churn_Risk__c,
                Adoption_Score__c,
                Support_Score__c,
                Engagement_Score__c,
                Financial_Score__c,
                Scored_On__c
            FROM Health_Score_Snapshot__c
            WHERE Account__c = :account.Id
        ];
        System.assertEquals(account.Health_Score__c, snapshot.Score__c, 'Snapshot mirrors the account state');
        System.assertEquals(80, snapshot.Adoption_Score__c);
        System.assertEquals(100, snapshot.Support_Score__c, 'No open cases');
        System.assertEquals(100, snapshot.Engagement_Score__c, 'NPS 100 maps to 100');
        System.assertNotEquals(
            null,
            snapshot.Financial_Score__c,
            'Active subscription provides financial signal'
        );
        System.assertEquals(Date.today(), snapshot.Scored_On__c);
    }

    @IsTest
    static void missingSignalsRenormalizeWeightsInsteadOfPunishing() {
        // No telemetry, no surveys: only Support (100) and Financial contribute.
        Account account = [SELECT Id FROM Account ORDER BY Name LIMIT 1];

        Test.startTest();
        new HealthScoreService().calculate(new Set<Id>{ account.Id }, System.AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Health_Score_Snapshot__c snapshot = [
            SELECT Score__c, Adoption_Score__c, Engagement_Score__c
            FROM Health_Score_Snapshot__c
            WHERE Account__c = :account.Id
        ];
        System.assertEquals(null, snapshot.Adoption_Score__c, 'No telemetry, no adoption value');
        System.assertEquals(null, snapshot.Engagement_Score__c, 'No surveys, no engagement value');
        // Support 100 (w .25) + Financial 80 (w .15): renormalized composite = 92.5 -> 92/93 band
        System.assert(
            snapshot.Score__c >= 90,
            'Composite must be a weighted average of available signals only, got ' + snapshot.Score__c
        );
    }

    @IsTest
    static void escalationToHighRiskPublishesChurnAlert() {
        Account account = [SELECT Id, OwnerId FROM Account ORDER BY Name LIMIT 1];
        account.Churn_Risk__c = 'Low';
        account.License_Utilization__c = 5; // shelfware
        update account;
        TestDataFactory.createNpsResponses(account, new List<Integer>{ 0, 1, 2 }); // all detractors
        TestDataFactory.createOpenCases(account, 6);

        Test.startTest();
        new HealthScoreService().calculate(new Set<Id>{ account.Id }, System.AccessLevel.SYSTEM_MODE);
        Test.getEventBus().deliver();
        Test.stopTest();

        account = [SELECT Churn_Risk__c FROM Account WHERE Id = :account.Id];
        System.assertEquals('High', account.Churn_Risk__c, 'This account is on fire');

        // The platform-event-triggered flow is the subscriber: it must have
        // created the outreach task for the account team.
        List<Task> tasks = [SELECT Subject, WhatId FROM Task WHERE WhatId = :account.Id];
        System.assertEquals(1, tasks.size(), 'Churn alert flow should create one outreach task');
    }

    @IsTest
    static void accountWithOnlySupportSignalScoresFromSupportAlone() {
        // No subscription, telemetry or surveys: Support (always measurable —
        // zero open cases IS a signal) carries the whole composite.
        Account bare = new Account(Name = 'No Signal Co');
        insert bare;

        Test.startTest();
        new HealthScoreService().calculate(new Set<Id>{ bare.Id }, System.AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        Health_Score_Snapshot__c snapshot = [
            SELECT Score__c, Support_Score__c, Adoption_Score__c, Engagement_Score__c, Financial_Score__c
            FROM Health_Score_Snapshot__c
            WHERE Account__c = :bare.Id
        ];
        System.assertEquals(100, snapshot.Score__c, 'Composite renormalizes to the only available dimension');
        System.assertEquals(100, snapshot.Support_Score__c);
        System.assertEquals(null, snapshot.Adoption_Score__c);
        System.assertEquals(null, snapshot.Engagement_Score__c);
        System.assertEquals(null, snapshot.Financial_Score__c);
    }
}
