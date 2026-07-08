/**
 * Read model for the CS portfolio dashboard. Everything is aggregate SOQL in
 * USER_MODE: each viewer sees the portfolio their sharing lets them see, and
 * the component cost stays flat regardless of how many accounts exist.
 */
public with sharing class PortfolioController {
    private static final Integer RENEWAL_HORIZON_DAYS = 90;
    private static final Integer MAX_PAGE_SIZE = 50;
    private static final Integer MAX_OFFSET = 2000;
    private static final Set<String> RISK_BANDS = new Set<String>{ 'Low', 'Medium', 'High' };

    @AuraEnabled(cacheable=true)
    public static PortfolioSummary getPortfolioSummary() {
        try {
            PortfolioSummary summary = new PortfolioSummary();

            Map<String, Integer> countsByRisk = new AccountSelector().countByChurnRisk();
            summary.lowRiskCount = countsByRisk.containsKey('Low') ? countsByRisk.get('Low') : 0;
            summary.mediumRiskCount = countsByRisk.containsKey('Medium') ? countsByRisk.get('Medium') : 0;
            summary.highRiskCount = countsByRisk.containsKey('High') ? countsByRisk.get('High') : 0;
            summary.scoredCustomerCount =
                summary.lowRiskCount +
                summary.mediumRiskCount +
                summary.highRiskCount;

            Map<String, Decimal> arrByRisk = new SubscriptionSelector().sumActiveArrByRisk();
            summary.activeArr = 0;
            for (Decimal arr : arrByRisk.values()) {
                summary.activeArr += arr;
            }
            summary.arrAtRisk = arrByRisk.containsKey('High') ? arrByRisk.get('High') : 0;

            AggregateResult renewalTotals = new OpportunitySelector()
                .openRenewalTotalsWithin(RENEWAL_HORIZON_DAYS);
            summary.renewalsDueCount = (Integer) renewalTotals.get('total');
            Decimal pipeline = (Decimal) renewalTotals.get('pipeline');
            summary.renewalsDueAmount = pipeline == null ? 0 : pipeline;
            summary.renewalHorizonDays = RENEWAL_HORIZON_DAYS;
            return summary;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountRow> getAccountsByRisk(
        String churnRisk,
        Integer pageSize,
        Integer offsetValue
    ) {
        if (!RISK_BANDS.contains(churnRisk)) {
            throw new AuraHandledException('Unknown risk band: ' + churnRisk);
        }
        Integer safePageSize = pageSize == null ||
            pageSize < 1 ||
            pageSize > MAX_PAGE_SIZE
            ? MAX_PAGE_SIZE
            : pageSize;
        Integer safeOffset = offsetValue == null || offsetValue < 0 ? 0 : Math.min(offsetValue, MAX_OFFSET);

        try {
            List<AccountRow> rows = new List<AccountRow>();
            for (
                Account account : new AccountSelector()
                    .selectByChurnRiskPaged(churnRisk, safePageSize, safeOffset)
            ) {
                AccountRow row = new AccountRow();
                row.accountId = account.Id;
                row.name = account.Name;
                row.healthScore = account.Health_Score__c;
                row.churnRisk = account.Churn_Risk__c;
                row.trend = account.Health_Trend__c;
                row.nps = account.NPS__c;
                row.csmName = account.CSM__r == null ? null : account.CSM__r.Name;
                rows.add(row);
            }
            return rows;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class PortfolioSummary {
        @AuraEnabled
        public Integer scoredCustomerCount;
        @AuraEnabled
        public Integer lowRiskCount;
        @AuraEnabled
        public Integer mediumRiskCount;
        @AuraEnabled
        public Integer highRiskCount;
        @AuraEnabled
        public Decimal activeArr;
        @AuraEnabled
        public Decimal arrAtRisk;
        @AuraEnabled
        public Integer renewalsDueCount;
        @AuraEnabled
        public Decimal renewalsDueAmount;
        @AuraEnabled
        public Integer renewalHorizonDays;
    }

    public class AccountRow {
        @AuraEnabled
        public Id accountId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Decimal healthScore;
        @AuraEnabled
        public String churnRisk;
        @AuraEnabled
        public String trend;
        @AuraEnabled
        public Decimal nps;
        @AuraEnabled
        public String csmName;
    }
}
