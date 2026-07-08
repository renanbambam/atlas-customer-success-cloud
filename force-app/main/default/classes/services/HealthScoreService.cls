/**
 * Orchestrates health scoring: bulk-loads one HealthScoreContext per account,
 * runs the metadata-configured dimension strategies, persists current state
 * on Account plus one Health_Score_Snapshot__c per run, and publishes
 * Churn_Risk_Alert__e when an account escalates to High risk.
 *
 * Write access level is chosen by the caller: the nightly batch passes
 * SYSTEM_MODE (ADR-0005); user-driven paths (controller, invocable) pass
 * USER_MODE so CRUD/FLS/sharing decide whether the user may persist scores.
 */
public inherited sharing class HealthScoreService {
    private static final String SOURCE = 'HealthScoreService';
    private static final Integer TREND_DEADBAND = 5;

    private final AccountSelector accountSelector = new AccountSelector();
    private final SubscriptionSelector subscriptionSelector = new SubscriptionSelector();
    private final CaseMetricsSelector caseMetricsSelector = new CaseMetricsSelector();
    private final SurveyResponseSelector surveySelector = new SurveyResponseSelector();
    private final HealthDimensionFactory dimensionFactory = new HealthDimensionFactory();

    public void calculate(Set<Id> accountIds, System.AccessLevel writeAccess) {
        List<HealthDimensionFactory.WeightedDimension> dimensions = dimensionFactory.buildActiveDimensions();
        if (dimensions.isEmpty()) {
            Logger.warn(SOURCE, 'No active health dimensions configured; scoring skipped', null);
            return;
        }

        Map<Id, HealthScoreContext> contextsByAccount = buildContexts(accountIds);
        List<Account> accountUpdates = new List<Account>();
        List<Health_Score_Snapshot__c> snapshots = new List<Health_Score_Snapshot__c>();
        List<Churn_Risk_Alert__e> alerts = new List<Churn_Risk_Alert__e>();

        for (HealthScoreContext context : contextsByAccount.values()) {
            ScoreResult result = scoreOne(context, dimensions);
            if (result == null) {
                // No dimension had any signal; an arbitrary score would be noise.
                continue;
            }
            accountUpdates.add(
                new Account(
                    Id = context.accountId,
                    Health_Score__c = result.composite,
                    Churn_Risk__c = result.risk,
                    Health_Trend__c = trendFor(context.previousScore, result.composite),
                    Health_Score_Updated__c = System.now()
                )
            );
            snapshots.add(result.snapshot);
            if (result.risk == 'High' && context.previousRisk != 'High') {
                alerts.add(
                    new Churn_Risk_Alert__e(
                        Account_Id__c = context.accountId,
                        Health_Score__c = result.composite,
                        Previous_Risk__c = context.previousRisk,
                        New_Risk__c = result.risk
                    )
                );
            }
        }

        UnitOfWork uow = new UnitOfWork(
            new List<SObjectType>{ Account.SObjectType, Health_Score_Snapshot__c.SObjectType },
            writeAccess
        );
        uow.registerDirty(accountUpdates);
        uow.registerNew(snapshots);
        uow.commitWork();

        if (!alerts.isEmpty()) {
            EventBus.publish(alerts);
        }
    }

    private ScoreResult scoreOne(
        HealthScoreContext context,
        List<HealthDimensionFactory.WeightedDimension> dimensions
    ) {
        Decimal weightedSum = 0;
        Decimal totalWeight = 0;
        Health_Score_Snapshot__c snapshot = new Health_Score_Snapshot__c(
            Account__c = context.accountId,
            Scored_On__c = Date.today()
        );

        for (HealthDimensionFactory.WeightedDimension dimension : dimensions) {
            Decimal dimensionScore = dimension.calculator.score(context);
            if (dimensionScore == null) {
                // Missing signal shifts weight to the dimensions that have data.
                continue;
            }
            weightedSum += dimensionScore * dimension.weight;
            totalWeight += dimension.weight;
            applyToSnapshot(snapshot, dimension.developerName, dimensionScore);
        }

        if (totalWeight == 0) {
            return null;
        }

        ScoreResult result = new ScoreResult();
        result.composite = (weightedSum / totalWeight).round();
        result.risk = riskFor(result.composite);
        snapshot.Score__c = result.composite;
        snapshot.Churn_Risk__c = result.risk;
        result.snapshot = snapshot;
        return result;
    }

    private void applyToSnapshot(
        Health_Score_Snapshot__c snapshot,
        String dimensionName,
        Decimal dimensionScore
    ) {
        // Dimensions added via metadata beyond the core four still count toward
        // the composite; they just have no dedicated snapshot column.
        switch on dimensionName {
            when 'Adoption' {
                snapshot.Adoption_Score__c = dimensionScore.round();
            }
            when 'Support' {
                snapshot.Support_Score__c = dimensionScore.round();
            }
            when 'Engagement' {
                snapshot.Engagement_Score__c = dimensionScore.round();
            }
            when 'Financial' {
                snapshot.Financial_Score__c = dimensionScore.round();
            }
        }
    }

    private Map<Id, HealthScoreContext> buildContexts(Set<Id> accountIds) {
        Map<Id, HealthScoreContext> contextsByAccount = new Map<Id, HealthScoreContext>();

        for (Account account : accountSelector.selectForScoringSystemMode(accountIds)) {
            HealthScoreContext context = new HealthScoreContext();
            context.accountId = account.Id;
            context.licenseUtilization = account.License_Utilization__c;
            context.monthlyActiveUsers = account.Monthly_Active_Users__c == null
                ? null
                : account.Monthly_Active_Users__c.intValue();
            context.previousScore = account.Health_Score__c;
            context.previousRisk = account.Churn_Risk__c;
            contextsByAccount.put(account.Id, context);
        }

        for (
            Subscription__c subscription : subscriptionSelector.selectActiveByAccountIdSystemMode(accountIds)
        ) {
            HealthScoreContext context = contextsByAccount.get(subscription.Account__c);
            if (context == null) {
                continue;
            }
            context.totalArr += subscription.Total_ARR__c == null ? 0 : subscription.Total_ARR__c;
            if (subscription.Renewal_Date__c != null) {
                Integer days = Date.today().daysBetween(subscription.Renewal_Date__c);
                if (context.daysToNearestRenewal == null || days < context.daysToNearestRenewal) {
                    context.daysToNearestRenewal = days;
                    context.autoRenew = subscription.Auto_Renew__c;
                }
            }
        }

        Map<Id, Integer> openCases = caseMetricsSelector.countOpenByAccountSystemMode(accountIds);
        Map<Id, Integer> escalations = caseMetricsSelector.countEscalatedLast90DaysByAccountSystemMode(
            accountIds
        );
        Map<Id, SurveyResponseSelector.NpsAggregate> npsAggregates = surveySelector.aggregateNpsByAccount(
            accountIds,
            AtlasSettings.npsWindowDays()
        );

        for (HealthScoreContext context : contextsByAccount.values()) {
            if (openCases.containsKey(context.accountId)) {
                context.openCases = openCases.get(context.accountId);
            }
            if (escalations.containsKey(context.accountId)) {
                context.escalatedCases90d = escalations.get(context.accountId);
            }
            SurveyResponseSelector.NpsAggregate aggregate = npsAggregates.get(context.accountId);
            if (aggregate != null) {
                context.npsScore = aggregate.npsScore();
                context.lastSurveyDate = aggregate.lastResponseDate;
            }
        }
        return contextsByAccount;
    }

    private static String riskFor(Decimal composite) {
        if (composite >= 70) {
            return 'Low';
        }
        return composite >= 40 ? 'Medium' : 'High';
    }

    private static String trendFor(Decimal previousScore, Decimal newScore) {
        if (previousScore == null) {
            return 'Stable';
        }
        if (newScore > previousScore + TREND_DEADBAND) {
            return 'Improving';
        }
        return newScore < previousScore - TREND_DEADBAND ? 'Declining' : 'Stable';
    }

    private class ScoreResult {
        Decimal composite;
        String risk;
        Health_Score_Snapshot__c snapshot;
    }
}
