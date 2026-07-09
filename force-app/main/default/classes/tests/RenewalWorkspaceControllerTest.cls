@IsTest
private class RenewalWorkspaceControllerTest {
    @TestSetup
    static void setup() {
        List<Account> accounts = AtlasTestDataFactory.createAccounts(3);
        List<Subscription__c> subscriptions = AtlasTestDataFactory.createSubscriptions(accounts, 'Draft');
        // Renewal dates 20 / 50 / 200 days out, then activate to open the pipeline.
        subscriptions[0].Renewal_Date__c = Date.today().addDays(20);
        subscriptions[1].Renewal_Date__c = Date.today().addDays(50);
        subscriptions[2].Renewal_Date__c = Date.today().addDays(200);
        for (Subscription__c subscription : subscriptions) {
            subscription.Status__c = 'Active';
        }
        update subscriptions;
    }

    @IsTest
    static void horizonFiltersAndOrdersByCloseDate() {
        Test.startTest();
        List<RenewalWorkspaceController.RenewalRow> within30 = RenewalWorkspaceController.getRenewals(
            30,
            50,
            0,
            'closeDate',
            'asc'
        );
        List<RenewalWorkspaceController.RenewalRow> within60 = RenewalWorkspaceController.getRenewals(
            60,
            50,
            0,
            'closeDate',
            'asc'
        );
        List<RenewalWorkspaceController.RenewalRow> within180 = RenewalWorkspaceController.getRenewals(
            180,
            50,
            0,
            'closeDate',
            'asc'
        );
        Test.stopTest();

        System.assertEquals(1, within30.size());
        System.assertEquals(2, within60.size());
        System.assertEquals(2, within180.size(), 'The 200-day renewal stays outside every horizon offered');
        System.assert(within60[0].closeDate <= within60[1].closeDate, 'Most urgent renewal first');
        System.assertEquals(20, within30[0].daysToClose);
        System.assertNotEquals(null, within30[0].accountName);
    }

    @IsTest
    static void sortDirectionIsAppliedOnTheServer() {
        Test.startTest();
        List<RenewalWorkspaceController.RenewalRow> descending = RenewalWorkspaceController.getRenewals(
            60,
            50,
            0,
            'closeDate',
            'desc'
        );
        Test.stopTest();

        System.assertEquals(2, descending.size());
        System.assert(
            descending[0].closeDate >= descending[1].closeDate,
            'Descending sort must reverse the server order, not just the loaded page'
        );
    }

    @IsTest
    static void unknownSortColumnFallsBackToCloseDate() {
        Test.startTest();
        // An unmapped column must not break the query — it falls back to close date.
        List<RenewalWorkspaceController.RenewalRow> rows = RenewalWorkspaceController.getRenewals(
            60,
            50,
            0,
            'notAColumn',
            'asc'
        );
        Test.stopTest();

        System.assertEquals(2, rows.size());
        System.assert(rows[0].closeDate <= rows[1].closeDate, 'Fallback order is close date ascending');
    }

    @IsTest
    static void paginationWalksTheList() {
        Test.startTest();
        List<RenewalWorkspaceController.RenewalRow> firstPage = RenewalWorkspaceController.getRenewals(
            60,
            1,
            0,
            'closeDate',
            'asc'
        );
        List<RenewalWorkspaceController.RenewalRow> secondPage = RenewalWorkspaceController.getRenewals(
            60,
            1,
            1,
            'closeDate',
            'asc'
        );
        Test.stopTest();

        System.assertEquals(1, firstPage.size());
        System.assertEquals(1, secondPage.size());
        System.assertNotEquals(firstPage[0].opportunityId, secondPage[0].opportunityId);
    }

    @IsTest
    static void unsupportedHorizonIsRejected() {
        try {
            RenewalWorkspaceController.getRenewals(7, 10, 0, 'closeDate', 'asc');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'Horizon whitelist held');
        }
    }
}
