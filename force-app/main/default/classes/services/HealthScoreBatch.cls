/**
 * Nightly scoring run over every account with an active subscription.
 * Scope 200 keeps the per-chunk budget comfortable: a handful of aggregate
 * queries and two DML statements per chunk, regardless of how many cases or
 * surveys each account has.
 */
public inherited sharing class HealthScoreBatch implements Database.Batchable<SObject> {
    private static final String SOURCE = 'HealthScoreBatch';
    public static final Integer BATCH_SCOPE = 200;
    public static final Integer PURGE_SCOPE = 2000;

    public Database.QueryLocator start(Database.BatchableContext context) {
        return new AccountSelector().activeCustomerLocator();
    }

    public void execute(Database.BatchableContext context, List<Account> scope) {
        try {
            new HealthScoreService()
                .calculate(new Map<Id, Account>(scope).keySet(), System.AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            // One failing chunk must not abort the whole nightly run.
            Logger.error(SOURCE, 'Scoring chunk failed', e);
        } finally {
            Logger.flush();
        }
    }

    public void finish(Database.BatchableContext context) {
        // Retention enforcement rides on the back of the nightly run (ADR-0008).
        // Chained batches don't execute in test context; the purge batch has
        // its own dedicated test.
        if (!Test.isRunningTest()) {
            Database.executeBatch(new HealthSnapshotPurgeBatch(), PURGE_SCOPE);
        }
    }
}
