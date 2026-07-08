@IsTest
private class SubscriptionControllerTest {
    @TestSetup
    static void setup() {
        List<Account> accounts = AtlasTestDataFactory.createAccounts(1);
        List<Subscription__c> subscriptions = AtlasTestDataFactory.createSubscriptions(accounts, 'Active');
        AtlasTestDataFactory.createItems(subscriptions, AtlasTestDataFactory.createProduct());
    }

    @IsTest
    static void returnsSubscriptionsWithRollupArr() {
        Account account = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<Subscription__c> rows = SubscriptionController.getSubscriptions(account.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals(120000, rows[0].Total_ARR__c, '100 seats x 1200/yr rolled up by the platform');
    }

    @IsTest
    static void userWithoutObjectPermissionIsDenied() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        User restrictedUser = AtlasTestDataFactory.createStandardUser();

        System.runAs(restrictedUser) {
            try {
                SubscriptionController.getSubscriptions(account.Id);
                System.assert(false, 'Standard User has no Subscription__c access');
            } catch (AuraHandledException e) {
                System.assert(true, 'Denied by USER_MODE');
            }
        }
    }
}
