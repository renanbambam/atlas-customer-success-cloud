/**
 * All Subscription__c reads.
 */
public inherited sharing class SubscriptionSelector {
    public List<Subscription__c> selectByIdWithAccount(Set<Id> subscriptionIds) {
        return [
            SELECT
                Id,
                Name,
                Account__c,
                Account__r.Name,
                Status__c,
                Start_Date__c,
                End_Date__c,
                Renewal_Date__c,
                Auto_Renew__c,
                Total_ARR__c,
                External_Id__c
            FROM Subscription__c
            WHERE Id IN :subscriptionIds
            WITH USER_MODE
        ];
    }

    public List<Subscription__c> selectByAccountId(Id accountId) {
        return [
            SELECT
                Id,
                Name,
                Status__c,
                Start_Date__c,
                End_Date__c,
                Renewal_Date__c,
                Days_To_Renewal__c,
                Auto_Renew__c,
                Total_ARR__c
            FROM Subscription__c
            WHERE Account__c = :accountId
            WITH USER_MODE
            ORDER BY End_Date__c DESC
            LIMIT 200
        ];
    }

    public List<Subscription__c> selectActiveByAccountIdSystemMode(Set<Id> accountIds) {
        // Scoring batch context (ADR-0005).
        return [
            SELECT Id, Account__c, Status__c, Renewal_Date__c, Auto_Renew__c, Total_ARR__c
            FROM Subscription__c
            WHERE Account__c IN :accountIds AND Status__c = 'Active'
            WITH SYSTEM_MODE
        ];
    }

    /** Portfolio dashboard: active ARR grouped by the account's churn-risk band. */
    public Map<String, Decimal> sumActiveArrByRisk() {
        Map<String, Decimal> arrByRisk = new Map<String, Decimal>();
        for (AggregateResult result : [
            SELECT Account__r.Churn_Risk__c risk, SUM(Total_ARR__c) total
            FROM Subscription__c
            WHERE Status__c = 'Active'
            WITH USER_MODE
            GROUP BY Account__r.Churn_Risk__c
        ]) {
            String risk = (String) result.get('risk');
            Decimal total = (Decimal) result.get('total');
            arrByRisk.put(risk == null ? 'Unscored' : risk, total == null ? 0 : total);
        }
        return arrByRisk;
    }

    public List<Subscription__c> selectByExternalIdSystemMode(Set<String> externalIds) {
        // Integration path: idempotent upsert resolution (ADR-0006).
        return [
            SELECT Id, External_Id__c, Account__c, Status__c
            FROM Subscription__c
            WHERE External_Id__c IN :externalIds
            WITH SYSTEM_MODE
        ];
    }
}
