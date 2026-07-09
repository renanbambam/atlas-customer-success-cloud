/**
 * All Opportunity reads used by the renewal pipeline.
 */
public inherited sharing class OpportunitySelector {
    public List<Opportunity> selectOpenRenewalsBySubscriptionId(Set<Id> subscriptionIds) {
        Id renewalRecordTypeId = renewalRecordTypeId();
        return [
            SELECT Id, Subscription__c, CloseDate, StageName, Amount
            FROM Opportunity
            WHERE
                Subscription__c IN :subscriptionIds
                AND RecordTypeId = :renewalRecordTypeId
                AND IsClosed = FALSE
            WITH USER_MODE
        ];
    }

    // Datatable column -> orderable SOQL field. The ORDER BY below is assembled
    // only from these hardcoded values, never from the caller's raw string, so
    // the sort cannot be used for SOQL injection.
    private static final Map<String, String> RENEWAL_SORT_FIELDS = new Map<String, String>{
        'opportunityUrl' => 'Name',
        'accountUrl' => 'Account.Name',
        'closeDate' => 'CloseDate',
        'daysToClose' => 'CloseDate',
        'amount' => 'Amount',
        'stageName' => 'StageName'
    };

    /**
     * Renewal workspace: one page of open renewals closing inside the horizon,
     * sorted on the server so the order is consistent across pages (client-side
     * sorting would only reorder the rows already loaded). Unknown sort columns
     * fall back to close date, the workspace's natural urgency order.
     */
    @SuppressWarnings('PMD.ApexSOQLInjection')
    public List<Opportunity> selectOpenRenewalsDueWithin(
        Integer horizonDays,
        Integer pageSize,
        Integer offsetRows,
        String sortBy,
        Boolean ascending
    ) {
        Id renewalRecordTypeId = renewalRecordTypeId();
        Date horizon = Date.today().addDays(horizonDays);
        String sortField = RENEWAL_SORT_FIELDS.containsKey(sortBy)
            ? RENEWAL_SORT_FIELDS.get(sortBy)
            : 'CloseDate';
        String direction = ascending == false ? 'DESC' : 'ASC';
        // Name is the tiebreaker so OFFSET paging stays deterministic across chunks.
        String query =
            'SELECT Id, Name, AccountId, Account.Name, CloseDate, Amount, StageName, Subscription__c ' +
            'FROM Opportunity ' +
            'WHERE RecordTypeId = :renewalRecordTypeId AND IsClosed = false AND CloseDate <= :horizon ' +
            'ORDER BY ' +
            sortField +
            ' ' +
            direction +
            ', Name ASC ' +
            'LIMIT :pageSize OFFSET :offsetRows';
        Map<String, Object> binds = new Map<String, Object>{
            'renewalRecordTypeId' => renewalRecordTypeId,
            'horizon' => horizon,
            'pageSize' => pageSize,
            'offsetRows' => offsetRows
        };
        return (List<Opportunity>) Database.queryWithBinds(query, binds, System.AccessLevel.USER_MODE);
    }

    /** Portfolio dashboard: count and pipeline value of renewals due inside the horizon. */
    public AggregateResult openRenewalTotalsWithin(Integer horizonDays) {
        Id renewalRecordTypeId = renewalRecordTypeId();
        Date horizon = Date.today().addDays(horizonDays);
        return [
            SELECT COUNT(Id) total, SUM(Amount) pipeline
            FROM Opportunity
            WHERE RecordTypeId = :renewalRecordTypeId AND IsClosed = FALSE AND CloseDate <= :horizon
            WITH USER_MODE
        ][0];
    }

    // Instance method on purpose: callers hold selector instances whose field
    // names shadow the class name (Apex identifiers are case-insensitive), so a
    // static reference like OpportunitySelector.renewalRecordTypeId() would not
    // compile from those call sites.
    public Id renewalRecordTypeId() {
        return SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Renewal').getRecordTypeId();
    }
}
