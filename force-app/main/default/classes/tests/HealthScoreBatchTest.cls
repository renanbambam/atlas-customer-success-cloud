@IsTest
private class HealthScoreBatchTest {
    @IsTest
    static void nightlyRunScoresEveryAccountWithAnActiveSubscription() {
        List<Account> customers = TestDataFactory.createAccounts(50);
        TestDataFactory.createSubscriptions(customers, 'Active');
        // An account with no active subscription must stay out of the run.
        Account prospect = new Account(Name = 'Prospect Only');
        insert prospect;

        Test.startTest();
        Database.executeBatch(new HealthScoreBatch(), HealthScoreBatch.BATCH_SCOPE);
        Test.stopTest();

        System.assertEquals(
            50,
            [SELECT COUNT() FROM Health_Score_Snapshot__c WHERE Scored_On__c = TODAY],
            'One snapshot per active customer'
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Health_Score_Snapshot__c WHERE Account__c = :prospect.Id],
            'Prospects without subscriptions are not scored'
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Account WHERE Id IN :customers AND Health_Score__c = NULL],
            'Every scored account carries its current score'
        );
    }

    @IsTest
    static void schedulerLaunchesTheBatch() {
        List<Account> customers = TestDataFactory.createAccounts(1);
        TestDataFactory.createSubscriptions(customers, 'Active');

        Test.startTest();
        String jobId = System.schedule(
            'HealthScoreScheduler test',
            '0 0 2 * * ?',
            new HealthScoreScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job must be accepted by the scheduler');
    }
}
