/**
 * Scheduled entry point of telemetry ingestion. Batch Apex (scope 100) is the
 * right chassis at portfolio scale: the platform pages the account set for
 * us, one callout per chunk. Transient failures are handed to
 * TelemetryRetryQueueable so a flaky five minutes at the provider does not
 * cost the whole nightly run.
 */
public inherited sharing class TelemetryIngestionBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return new AccountSelector().telemetryAccountLocator();
    }

    public void execute(Database.BatchableContext context, List<Account> scope) {
        Set<Id> accountIds = new Map<Id, Account>(scope).keySet();
        Boolean done = new TelemetryIngestionService().ingest(accountIds, 1);
        if (!done && !Test.isRunningTest()) {
            System.enqueueJob(new TelemetryRetryQueueable(accountIds, 2));
        }
    }

    public void finish(Database.BatchableContext context) {
        Logger.flush();
    }
}
