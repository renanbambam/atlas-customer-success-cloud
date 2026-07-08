@IsTest
private class RecalculateHealthScoreActionTest {
    @IsTest
    static void invocableRecalculatesForFlowCallers() {
        List<Account> accounts = AtlasTestDataFactory.createAccounts(2);
        AtlasTestDataFactory.createSubscriptions(accounts, 'Active');

        Test.startTest();
        RecalculateHealthScoreAction.recalculate(new List<Id>(new Map<Id, Account>(accounts).keySet()));
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Account WHERE Id IN :accounts AND Health_Score__c = NULL],
            'Both accounts must carry a score after the action runs'
        );
    }
}
