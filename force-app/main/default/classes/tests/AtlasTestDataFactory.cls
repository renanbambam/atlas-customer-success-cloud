/**
 * Single source of valid test data. Tests never hand-roll records: when the
 * schema grows a required field, this is the only place that changes.
 */
@IsTest
public class AtlasTestDataFactory {
    public static List<Account> createAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Test Customer ' + i, Billing_System_Id__c = 'BILL-' + i));
        }
        insert accounts;
        return accounts;
    }

    public static Product2 createProduct() {
        Product2 product = new Product2(Name = 'Atlas Platform License', IsActive = true);
        insert product;
        return product;
    }

    public static List<Subscription__c> createSubscriptions(List<Account> accounts, String status) {
        List<Subscription__c> subscriptions = new List<Subscription__c>();
        for (Account account : accounts) {
            subscriptions.add(
                new Subscription__c(
                    Account__c = account.Id,
                    Status__c = status,
                    Start_Date__c = Date.today().addMonths(-6),
                    End_Date__c = Date.today().addMonths(6),
                    Renewal_Date__c = status == 'Draft' ? null : Date.today().addMonths(6),
                    External_Id__c = 'EXT-' + account.Id
                )
            );
        }
        insert subscriptions;
        return subscriptions;
    }

    public static List<Subscription_Item__c> createItems(
        List<Subscription__c> subscriptions,
        Product2 product
    ) {
        List<Subscription_Item__c> items = new List<Subscription_Item__c>();
        for (Subscription__c subscription : subscriptions) {
            items.add(
                new Subscription_Item__c(
                    Subscription__c = subscription.Id,
                    Product__c = product.Id,
                    Quantity__c = 100,
                    Unit_Annual_Price__c = 1200
                )
            );
        }
        insert items;
        return items;
    }

    public static List<Survey_Response__c> createNpsResponses(Account account, List<Integer> scores) {
        List<Survey_Response__c> responses = new List<Survey_Response__c>();
        for (Integer score : scores) {
            responses.add(
                new Survey_Response__c(
                    Account__c = account.Id,
                    Type__c = 'NPS',
                    Score__c = score,
                    Response_Date__c = Date.today()
                )
            );
        }
        insert responses;
        return responses;
    }

    public static List<Case> createOpenCases(Account account, Integer count) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(
                new Case(AccountId = account.Id, Subject = 'Issue ' + i, Status = 'New', Origin = 'Web')
            );
        }
        insert cases;
        return cases;
    }

    /** Standard user with no Atlas permissions — the negative-test persona. */
    public static User createStandardUser() {
        // Standard profile names are localized per org language, so select
        // structurally: any full-license, non-admin standard profile works —
        // Atlas grants come exclusively from permission sets.
        Profile standardProfile = [
            SELECT Id
            FROM Profile
            WHERE
                UserType = 'Standard'
                AND PermissionsModifyAllData = FALSE
                AND PermissionsViewAllData = FALSE
                AND UserLicense.Name = 'Salesforce'
            ORDER BY Name
            LIMIT 1
        ];
        User testUser = new User(
            ProfileId = standardProfile.Id,
            Username = 'atlas.test.' +
                System.currentTimeMillis() +
                Math.round(Math.random() * 100000) +
                '@example.com',
            Email = 'atlas.test@example.com',
            FirstName = 'Atlas',
            LastName = 'Tester',
            Alias = 'atlast',
            TimeZoneSidKey = 'America/Sao_Paulo',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        return testUser;
    }

    public static void assignPermissionSets(User targetUser, List<String> permissionSetNames) {
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet permissionSet : [
            SELECT Id
            FROM PermissionSet
            WHERE Name IN :permissionSetNames
        ]) {
            assignments.add(
                new PermissionSetAssignment(AssigneeId = targetUser.Id, PermissionSetId = permissionSet.Id)
            );
        }
        // Setup-object DML in its own runAs block so callers can freely mix it
        // with regular DML in the same test method.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert assignments;
        }
    }
}
