/**
 * Deletes snapshots older than the retention window (Atlas_Setting__mdt).
 * Keeps Health_Score_Snapshot__c out of LDV trouble — see ADR-0008.
 */
public inherited sharing class HealthSnapshotPurgeBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        Date cutoff = Date.today().addMonths(-AtlasSettings.snapshotRetentionMonths());
        return new HealthScoreSnapshotSelector().purgeLocator(cutoff);
    }

    public void execute(Database.BatchableContext context, List<Health_Score_Snapshot__c> scope) {
        Database.delete(scope, false, System.AccessLevel.SYSTEM_MODE);
    }

    public void finish(Database.BatchableContext context) {
        Logger.flush();
    }
}
