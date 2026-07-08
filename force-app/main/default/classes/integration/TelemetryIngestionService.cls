/**
 * Pulls usage metrics for a page of accounts and writes them onto Account
 * telemetry fields (SYSTEM_MODE — integration path, ADR-0005). Shared by the
 * scheduled batch (first attempt) and the retry queueable (subsequent
 * attempts), so retry policy lives in exactly one place.
 */
public inherited sharing class TelemetryIngestionService {
    private static final String SOURCE = 'TelemetryIngestionService';

    private final AccountSelector accountSelector = new AccountSelector();
    private final TelemetryClient client;

    public TelemetryIngestionService() {
        this(new TelemetryClient());
    }

    @TestVisible
    private TelemetryIngestionService(TelemetryClient client) {
        this.client = client;
    }

    /**
     * @return true when the page is done (success or permanent failure);
     *         false when the caller should schedule a retry.
     */
    public Boolean ingest(Set<Id> accountIds, Integer attempt) {
        List<Account> accounts = accountSelector.selectBillingInfoByIdSystemMode(accountIds);
        if (accounts.isEmpty()) {
            return true;
        }
        Map<String, Id> accountIdByKey = new Map<String, Id>();
        List<String> accountKeys = new List<String>();
        for (Account account : accounts) {
            accountIdByKey.put(account.Billing_System_Id__c, account.Id);
            accountKeys.add(account.Billing_System_Id__c);
        }

        TelemetryClient.Result result = client.fetchUsage(accountKeys);

        if (result.success) {
            List<Account> updates = new List<Account>();
            for (TelemetryUsageDTO usage : result.usages) {
                Id accountId = accountIdByKey.get(usage.accountKey);
                if (accountId == null) {
                    Logger.warn(SOURCE, 'Telemetry returned unknown account key', usage.accountKey);
                    continue;
                }
                updates.add(
                    new Account(
                        Id = accountId,
                        Monthly_Active_Users__c = usage.monthlyActiveUsers,
                        License_Utilization__c = usage.licenseUtilization
                    )
                );
            }
            UnitOfWork uow = new UnitOfWork(
                new List<SObjectType>{ Account.SObjectType },
                System.AccessLevel.SYSTEM_MODE
            );
            uow.registerDirty(updates);
            uow.commitWork();
            Logger.flush();
            return true;
        }

        if (result.retryable && attempt < AtlasSettings.maxCalloutAttempts()) {
            return false;
        }

        Logger.error(
            SOURCE,
            'Telemetry ingestion abandoned after attempt ' + attempt + ': ' + result.error,
            String.valueOf(accountIds.size()) + ' accounts'
        );
        Logger.flush();
        return true;
    }
}
