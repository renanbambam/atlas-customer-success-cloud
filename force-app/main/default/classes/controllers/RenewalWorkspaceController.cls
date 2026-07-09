/**
 * Read model for the renewal workspace: open renewal opportunities inside a
 * chosen horizon, paged for lazy loading. USER_MODE end to end — a CSM works
 * their own book, a manager (role hierarchy) sees the team's.
 */
public with sharing class RenewalWorkspaceController {
    private static final Integer MAX_PAGE_SIZE = 50;
    private static final Integer MAX_OFFSET = 2000;
    private static final Set<Integer> ALLOWED_HORIZONS = new Set<Integer>{ 30, 60, 90, 180 };

    @AuraEnabled(cacheable=true)
    public static List<RenewalRow> getRenewals(
        Integer horizonDays,
        Integer pageSize,
        Integer offsetValue,
        String sortBy,
        String sortDirection
    ) {
        if (!ALLOWED_HORIZONS.contains(horizonDays)) {
            throw new AuraHandledException('Unsupported horizon: ' + horizonDays);
        }
        Integer safePageSize = pageSize == null ||
            pageSize < 1 ||
            pageSize > MAX_PAGE_SIZE
            ? MAX_PAGE_SIZE
            : pageSize;
        Integer safeOffset = offsetValue == null || offsetValue < 0 ? 0 : Math.min(offsetValue, MAX_OFFSET);
        // The selector allowlists sortBy; here we only decide direction (default ascending).
        Boolean ascending = !(sortDirection != null && sortDirection.equalsIgnoreCase('desc'));

        try {
            List<RenewalRow> rows = new List<RenewalRow>();
            for (
                Opportunity renewal : new OpportunitySelector()
                    .selectOpenRenewalsDueWithin(horizonDays, safePageSize, safeOffset, sortBy, ascending)
            ) {
                RenewalRow row = new RenewalRow();
                row.opportunityId = renewal.Id;
                row.name = renewal.Name;
                row.accountId = renewal.AccountId;
                row.accountName = renewal.Account == null ? null : renewal.Account.Name;
                row.closeDate = renewal.CloseDate;
                row.amount = renewal.Amount;
                row.stageName = renewal.StageName;
                row.daysToClose = Date.today().daysBetween(renewal.CloseDate);
                rows.add(row);
            }
            return rows;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class RenewalRow {
        @AuraEnabled
        public Id opportunityId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Id accountId;
        @AuraEnabled
        public String accountName;
        @AuraEnabled
        public Date closeDate;
        @AuraEnabled
        public Decimal amount;
        @AuraEnabled
        public String stageName;
        @AuraEnabled
        public Integer daysToClose;
    }
}
