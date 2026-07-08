@IsTest
private class HealthSnapshotPurgeBatchTest {
    @IsTest
    static void deletesOnlySnapshotsBeyondTheRetentionWindow() {
        Account account = TestDataFactory.createAccounts(1)[0];
        Date cutoffSafe = Date.today().addMonths(-1);
        Date beyondRetention = Date.today().addMonths(-(AtlasSettings.snapshotRetentionMonths() + 1));

        insert new List<Health_Score_Snapshot__c>{
            new Health_Score_Snapshot__c(
                Account__c = account.Id,
                Score__c = 80,
                Churn_Risk__c = 'Low',
                Scored_On__c = cutoffSafe
            ),
            new Health_Score_Snapshot__c(
                Account__c = account.Id,
                Score__c = 60,
                Churn_Risk__c = 'Medium',
                Scored_On__c = beyondRetention
            )
        };

        Test.startTest();
        Database.executeBatch(new HealthSnapshotPurgeBatch(), 200);
        Test.stopTest();

        List<Health_Score_Snapshot__c> remaining = [SELECT Scored_On__c FROM Health_Score_Snapshot__c];
        System.assertEquals(1, remaining.size(), 'Only the stale snapshot is purged');
        System.assertEquals(cutoffSafe, remaining[0].Scored_On__c);
    }
}
