/**
 * Nightly trigger for the scoring batch. The cron expression lives in org
 * configuration (System.schedule call in the deploy runbook), not in code.
 */
public inherited sharing class HealthScoreScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        Database.executeBatch(new HealthScoreBatch(), HealthScoreBatch.BATCH_SCOPE);
    }
}
