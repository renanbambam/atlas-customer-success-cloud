@IsTest
private class PortfolioControllerTest {
    @TestSetup
    static void setup() {
        List<Account> accounts = TestDataFactory.createAccounts(6);
        // 3 Low / 2 Medium / 1 High
        for (Integer i = 0; i < accounts.size(); i++) {
            accounts[i].Churn_Risk__c = i < 3 ? 'Low' : (i < 5 ? 'Medium' : 'High');
            accounts[i].Health_Score__c = 90 - (i * 10);
        }
        update accounts;

        List<Subscription__c> subscriptions = TestDataFactory.createSubscriptions(accounts, 'Active');
        TestDataFactory.createItems(subscriptions, TestDataFactory.createProduct());
    }

    @IsTest
    static void summaryAggregatesRiskCountsArrAndRenewalPipeline() {
        Test.startTest();
        PortfolioController.PortfolioSummary summary = PortfolioController.getPortfolioSummary();
        Test.stopTest();

        System.assertEquals(6, summary.scoredCustomerCount);
        System.assertEquals(3, summary.lowRiskCount);
        System.assertEquals(2, summary.mediumRiskCount);
        System.assertEquals(1, summary.highRiskCount);
        // 6 subscriptions x 100 seats x 1200/yr
        System.assertEquals(720000, summary.activeArr);
        System.assertEquals(120000, summary.arrAtRisk, 'Only the High-risk account ARR counts as at-risk');
        // Renewal opportunities were created by activation; renewal date is ~6 months out
        System.assertEquals(0, summary.renewalsDueCount, 'Nothing renews inside 90 days in this dataset');
        System.assertEquals(90, summary.renewalHorizonDays);
    }

    @IsTest
    static void accountListIsPagedAndOrderedByScore() {
        Test.startTest();
        List<PortfolioController.AccountRow> firstPage = PortfolioController.getAccountsByRisk('Low', 2, 0);
        List<PortfolioController.AccountRow> secondPage = PortfolioController.getAccountsByRisk('Low', 2, 2);
        Test.stopTest();

        System.assertEquals(2, firstPage.size());
        System.assertEquals(1, secondPage.size(), '3 Low accounts paged 2+1');
        System.assert(
            firstPage[0].healthScore <= firstPage[1].healthScore,
            'Worst score first — this is a triage list'
        );
    }

    @IsTest
    static void unknownRiskBandIsRejected() {
        try {
            PortfolioController.getAccountsByRisk('Catastrophic', 10, 0);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'Whitelist held');
        }
    }

    @IsTest
    static void userWithoutAtlasPermissionsSeesDenialNotData() {
        User restrictedUser = TestDataFactory.createStandardUser();
        System.runAs(restrictedUser) {
            try {
                PortfolioController.getPortfolioSummary();
                System.assert(false, 'Standard User has no Subscription__c read access');
            } catch (AuraHandledException e) {
                System.assert(true, 'USER_MODE aggregate was blocked');
            }
        }
    }
}
