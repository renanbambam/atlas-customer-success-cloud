/**
 * Declarative surface of the scoring engine: lets flows and quick actions
 * request an on-demand recalculation without duplicating any scoring logic.
 * Runs in USER_MODE — whether the requester may persist scores is decided by
 * their permissions, not by this class.
 */
public with sharing class RecalculateHealthScoreAction {
    @InvocableMethod(
        label='Recalculate Health Score'
        description='Recalculates the customer health score for the given accounts immediately.'
        category='Atlas Customer Success'
    )
    public static void recalculate(List<Id> accountIds) {
        new HealthScoreService().calculate(new Set<Id>(accountIds), System.AccessLevel.USER_MODE);
    }
}
