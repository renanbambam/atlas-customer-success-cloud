/**
 * Retry vehicle for one page of telemetry ingestion. The platform has no
 * native callout retry; chaining a Queueable with an attempt counter is the
 * documented pattern. The cap comes from Atlas_Setting__mdt and is enforced
 * inside TelemetryIngestionService.
 */
public inherited sharing class TelemetryRetryQueueable implements Queueable, Database.AllowsCallouts {
    private final Set<Id> accountIds;
    private final Integer attempt;

    public TelemetryRetryQueueable(Set<Id> accountIds, Integer attempt) {
        this.accountIds = accountIds;
        this.attempt = attempt;
    }

    public void execute(QueueableContext context) {
        Boolean done = new TelemetryIngestionService().ingest(accountIds, attempt);
        if (!done && !Test.isRunningTest()) {
            System.enqueueJob(new TelemetryRetryQueueable(accountIds, attempt + 1));
        }
    }
}
