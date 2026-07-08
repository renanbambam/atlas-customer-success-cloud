/**
 * All Account reads. User-facing paths run WITH USER_MODE; the two
 * system-mode methods exist solely for the async jobs listed in ADR-0005 and
 * say so in their names.
 */
public inherited sharing class AccountSelector {
    public List<Account> selectById(Set<Id> accountIds) {
        return [
            SELECT
                Id,
                Name,
                Health_Score__c,
                Churn_Risk__c,
                Health_Trend__c,
                NPS__c,
                CSM__c,
                Health_Score_Updated__c,
                Monthly_Active_Users__c,
                License_Utilization__c,
                Billing_System_Id__c
            FROM Account
            WHERE Id IN :accountIds
            WITH USER_MODE
        ];
    }

    public List<Account> selectByBillingSystemIdSystemMode(Set<String> billingIds) {
        // Integration path: the billing sync must resolve accounts across the
        // whole org regardless of the integration user's sharing.
        return [
            SELECT Id, Billing_System_Id__c
            FROM Account
            WHERE Billing_System_Id__c IN :billingIds
            WITH SYSTEM_MODE
        ];
    }

    public List<Account> selectForScoringSystemMode(Set<Id> accountIds) {
        // Scoring batch context (ADR-0005): the nightly engine scores the
        // entire portfolio independently of who scheduled it.
        return [
            SELECT Id, Health_Score__c, Churn_Risk__c, NPS__c, Monthly_Active_Users__c, License_Utilization__c
            FROM Account
            WHERE Id IN :accountIds
            WITH SYSTEM_MODE
        ];
    }

    public List<Account> selectBillingInfoByIdSystemMode(Set<Id> accountIds) {
        return [
            SELECT Id, Billing_System_Id__c
            FROM Account
            WHERE Id IN :accountIds AND Billing_System_Id__c != NULL
            WITH SYSTEM_MODE
        ];
    }

    public Database.QueryLocator telemetryAccountLocator() {
        // Batch start method; runs in the ingestion batch's system context.
        return Database.getQueryLocator(
            [SELECT Id, Billing_System_Id__c FROM Account WHERE Billing_System_Id__c != NULL]
        );
    }

    /** Portfolio dashboard: how many accounts sit in each churn-risk band. */
    public Map<String, Integer> countByChurnRisk() {
        Map<String, Integer> countsByRisk = new Map<String, Integer>();
        for (AggregateResult result : [
            SELECT Churn_Risk__c risk, COUNT(Id) total
            FROM Account
            WHERE Churn_Risk__c != NULL
            WITH USER_MODE
            GROUP BY Churn_Risk__c
        ]) {
            countsByRisk.put((String) result.get('risk'), (Integer) result.get('total'));
        }
        return countsByRisk;
    }

    /**
     * Paged worklist for the dashboard. OFFSET pagination is deliberate: the
     * list is a triage view capped well below the platform's 2000-row OFFSET
     * ceiling, not a data-export surface.
     */
    public List<Account> selectByChurnRiskPaged(String churnRisk, Integer pageSize, Integer offsetRows) {
        return [
            SELECT
                Id,
                Name,
                Health_Score__c,
                Churn_Risk__c,
                Health_Trend__c,
                NPS__c,
                CSM__r.Name,
                Health_Score_Updated__c
            FROM Account
            WHERE Churn_Risk__c = :churnRisk
            WITH USER_MODE
            ORDER BY Health_Score__c ASC NULLS LAST, Name
            LIMIT :pageSize
            OFFSET :offsetRows
        ];
    }

    public Database.QueryLocator activeCustomerLocator() {
        // Batch start method; runs in the batch's system context by design.
        return Database.getQueryLocator(
            [
                SELECT Id
                FROM Account
                WHERE Id IN (SELECT Account__c FROM Subscription__c WHERE Status__c = 'Active')
            ]
        );
    }
}
