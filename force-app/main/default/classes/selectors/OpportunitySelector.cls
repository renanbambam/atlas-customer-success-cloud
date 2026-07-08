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

    /** Renewal workspace: open renewals closing inside the horizon, oldest first. */
    public List<Opportunity> selectOpenRenewalsDueWithin(
        Integer horizonDays,
        Integer pageSize,
        Integer offsetRows
    ) {
        Id renewalRecordTypeId = renewalRecordTypeId();
        Date horizon = Date.today().addDays(horizonDays);
        return [
            SELECT Id, Name, AccountId, Account.Name, CloseDate, Amount, StageName, Subscription__c
            FROM Opportunity
            WHERE RecordTypeId = :renewalRecordTypeId AND IsClosed = FALSE AND CloseDate <= :horizon
            WITH USER_MODE
            ORDER BY CloseDate ASC, Name
            LIMIT :pageSize
            OFFSET :offsetRows
        ];
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
