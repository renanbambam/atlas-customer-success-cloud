/**
 * LWC-facing read model for the health score panel. Thin by design: shapes
 * data, delegates everything else. All reads run WITH USER_MODE through the
 * selectors, so the panel shows exactly what the viewer is allowed to see.
 */
public with sharing class HealthScoreController {
    private static final Integer TREND_POINTS = 30;

    @AuraEnabled(cacheable=true)
    public static HealthSummary getHealthSummary(Id accountId) {
        try {
            List<Account> accounts = new AccountSelector().selectById(new Set<Id>{ accountId });
            if (accounts.isEmpty()) {
                throw new AuraHandledException('Account not found or not accessible');
            }
            Account account = accounts[0];

            HealthSummary summary = new HealthSummary();
            summary.score = account.Health_Score__c;
            summary.churnRisk = account.Churn_Risk__c;
            summary.trend = account.Health_Trend__c;
            summary.nps = account.NPS__c;
            summary.updatedAt = account.Health_Score_Updated__c;

            List<Health_Score_Snapshot__c> snapshots = new HealthScoreSnapshotSelector()
                .selectRecentByAccountId(accountId, TREND_POINTS);
            if (!snapshots.isEmpty()) {
                Health_Score_Snapshot__c latest = snapshots[0];
                summary.adoptionScore = latest.Adoption_Score__c;
                summary.supportScore = latest.Support_Score__c;
                summary.engagementScore = latest.Engagement_Score__c;
                summary.financialScore = latest.Financial_Score__c;
            }
            // Oldest-first so the sparkline reads left to right.
            for (Integer i = snapshots.size() - 1; i >= 0; i--) {
                TrendPoint point = new TrendPoint();
                point.scoredOn = snapshots[i].Scored_On__c;
                point.score = snapshots[i].Score__c;
                summary.history.add(point);
            }
            return summary;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void recalculate(Id accountId) {
        try {
            new HealthScoreService().calculate(new Set<Id>{ accountId }, System.AccessLevel.USER_MODE);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class HealthSummary {
        @AuraEnabled
        public Decimal score;
        @AuraEnabled
        public String churnRisk;
        @AuraEnabled
        public String trend;
        @AuraEnabled
        public Decimal nps;
        @AuraEnabled
        public Datetime updatedAt;
        @AuraEnabled
        public Decimal adoptionScore;
        @AuraEnabled
        public Decimal supportScore;
        @AuraEnabled
        public Decimal engagementScore;
        @AuraEnabled
        public Decimal financialScore;
        @AuraEnabled
        public List<TrendPoint> history = new List<TrendPoint>();
    }

    public class TrendPoint {
        @AuraEnabled
        public Date scoredOn;
        @AuraEnabled
        public Decimal score;
    }
}
