@IsTest
private class HealthScoreControllerTest {
    @TestSetup
    static void setup() {
        List<Account> accounts = TestDataFactory.createAccounts(1);
        TestDataFactory.createSubscriptions(accounts, 'Active');
    }

    @IsTest
    static void summaryShapesAccountStateAndTrendHistory() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        insert new List<Health_Score_Snapshot__c>{
            new Health_Score_Snapshot__c(
                Account__c = account.Id,
                Score__c = 70,
                Churn_Risk__c = 'Low',
                Scored_On__c = Date.today().addDays(-2),
                Adoption_Score__c = 60
            ),
            new Health_Score_Snapshot__c(
                Account__c = account.Id,
                Score__c = 75,
                Churn_Risk__c = 'Low',
                Scored_On__c = Date.today().addDays(-1),
                Adoption_Score__c = 65
            )
        };
        account.Health_Score__c = 75;
        account.Churn_Risk__c = 'Low';
        account.Health_Trend__c = 'Improving';
        update account;

        Test.startTest();
        HealthScoreController.HealthSummary summary = HealthScoreController.getHealthSummary(account.Id);
        Test.stopTest();

        System.assertEquals(75, summary.score);
        System.assertEquals('Low', summary.churnRisk);
        System.assertEquals('Improving', summary.trend);
        System.assertEquals(65, summary.adoptionScore, 'Breakdown comes from the latest snapshot');
        System.assertEquals(2, summary.history.size());
        System.assertEquals(70, summary.history[0].score, 'History must be oldest-first for the sparkline');
    }

    @IsTest
    static void recalculatePersistsAFreshScore() {
        Account account = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        HealthScoreController.recalculate(account.Id);
        Test.stopTest();

        account = [SELECT Health_Score__c, Health_Score_Updated__c FROM Account WHERE Id = :account.Id];
        System.assertNotEquals(null, account.Health_Score__c);
        System.assertNotEquals(null, account.Health_Score_Updated__c);
    }

    @IsTest
    static void userWithoutAtlasPermissionsIsDenied() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        User restrictedUser = TestDataFactory.createStandardUser();

        System.runAs(restrictedUser) {
            try {
                HealthScoreController.getHealthSummary(account.Id);
                System.assert(false, 'Standard User cannot see Atlas data');
            } catch (AuraHandledException e) {
                System.assert(true, 'USER_MODE selectors surfaced the denial');
            }
        }
    }

    @IsTest
    static void csmPermissionSetGrantsReadAccess() {
        Account account = [SELECT Id, OwnerId FROM Account LIMIT 1];
        User csmUser = TestDataFactory.createStandardUser();
        TestDataFactory.assignPermissionSets(csmUser, new List<String>{ 'Atlas_CS_Base', 'Atlas_CSM' });
        // Private OWD: give the CSM record access the way the org would — ownership.
        account.OwnerId = csmUser.Id;
        update account;

        System.runAs(csmUser) {
            HealthScoreController.HealthSummary summary = HealthScoreController.getHealthSummary(account.Id);
            System.assertNotEquals(null, summary, 'Base + CSM permission sets are sufficient to read');
        }
    }
}
