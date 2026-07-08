/**
 * Aggregate Case reads for the health score engine. Aggregates instead of row
 * loads: 200 accounts with thousands of cases each must stay inside one query
 * and a few hundred aggregate rows.
 */
public inherited sharing class CaseMetricsSelector {
    public Map<Id, Integer> countOpenByAccountSystemMode(Set<Id> accountIds) {
        // Scoring batch context (ADR-0005).
        Map<Id, Integer> openByAccount = new Map<Id, Integer>();
        for (AggregateResult result : [
            SELECT AccountId accId, COUNT(Id) total
            FROM Case
            WHERE AccountId IN :accountIds AND IsClosed = FALSE
            WITH SYSTEM_MODE
            GROUP BY AccountId
        ]) {
            openByAccount.put((Id) result.get('accId'), (Integer) result.get('total'));
        }
        return openByAccount;
    }

    public Map<Id, Integer> countEscalatedLast90DaysByAccountSystemMode(Set<Id> accountIds) {
        Map<Id, Integer> escalatedByAccount = new Map<Id, Integer>();
        Date windowStart = Date.today().addDays(-90);
        for (AggregateResult result : [
            SELECT AccountId accId, COUNT(Id) total
            FROM Case
            WHERE AccountId IN :accountIds AND IsEscalated = TRUE AND CreatedDate >= :windowStart
            WITH SYSTEM_MODE
            GROUP BY AccountId
        ]) {
            escalatedByAccount.put((Id) result.get('accId'), (Integer) result.get('total'));
        }
        return escalatedByAccount;
    }
}
