/**
 * All Health_Score_Snapshot__c reads.
 */
public inherited sharing class HealthScoreSnapshotSelector {
    public List<Health_Score_Snapshot__c> selectRecentByAccountId(Id accountId, Integer maxRows) {
        return [
            SELECT
                Id,
                Score__c,
                Churn_Risk__c,
                Adoption_Score__c,
                Support_Score__c,
                Engagement_Score__c,
                Financial_Score__c,
                Scored_On__c
            FROM Health_Score_Snapshot__c
            WHERE Account__c = :accountId
            WITH USER_MODE
            ORDER BY Scored_On__c DESC
            LIMIT :maxRows
        ];
    }

    public Database.QueryLocator purgeLocator(Date cutoff) {
        // Batch start method; runs in the purge batch's system context (ADR-0008).
        return Database.getQueryLocator(
            [SELECT Id FROM Health_Score_Snapshot__c WHERE Scored_On__c < :cutoff]
        );
    }
}
