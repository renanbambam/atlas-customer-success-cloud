/**
 * Nightly trigger for telemetry ingestion. Scheduling itself (cron, hour) is
 * org configuration; this class only knows how to launch the batch.
 */
public inherited sharing class TelemetryIngestionScheduler implements Schedulable {
    public static final Integer BATCH_SCOPE = 100;

    public void execute(SchedulableContext context) {
        Database.executeBatch(new TelemetryIngestionBatch(), BATCH_SCOPE);
    }
}
