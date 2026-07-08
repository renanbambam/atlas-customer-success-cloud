@IsTest
private class TelemetryIngestionTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createAccounts(3);
    }

    private static Set<Id> accountIds() {
        return new Map<Id, Account>([SELECT Id FROM Account]).keySet();
    }

    @IsTest
    static void successfulIngestionUpdatesAccountTelemetryFields() {
        List<Account> accounts = [SELECT Id, Billing_System_Id__c FROM Account];
        List<TelemetryUsageDTO> usages = new List<TelemetryUsageDTO>();
        for (Account account : accounts) {
            TelemetryUsageDTO usage = new TelemetryUsageDTO();
            usage.accountKey = account.Billing_System_Id__c;
            usage.monthlyActiveUsers = 500;
            usage.licenseUtilization = 76.5;
            usages.add(usage);
        }
        Test.setMock(HttpCalloutMock.class, TelemetryCalloutMock.success(usages));

        Test.startTest();
        Boolean done = new TelemetryIngestionService().ingest(accountIds(), 1);
        Test.stopTest();

        System.assert(done, 'Successful page is done');
        for (Account account : [SELECT Monthly_Active_Users__c, License_Utilization__c FROM Account]) {
            System.assertEquals(500, account.Monthly_Active_Users__c);
            System.assertEquals(76.5, account.License_Utilization__c);
        }
    }

    @IsTest
    static void serverErrorRequestsRetryUntilAttemptsExhaust() {
        Test.setMock(HttpCalloutMock.class, TelemetryCalloutMock.failing(503));
        TelemetryIngestionService service = new TelemetryIngestionService();

        Test.startTest();
        System.assertEquals(false, service.ingest(accountIds(), 1), 'First 5xx should ask for a retry');
        System.assertEquals(
            true,
            service.ingest(accountIds(), AtlasSettings.maxCalloutAttempts()),
            'Final attempt gives up instead of retrying forever'
        );
        Test.getEventBus().deliver();
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM App_Log__c WHERE Level__c = 'ERROR'],
            'Exhausted retries must leave an operational log'
        );
    }

    @IsTest
    static void clientErrorIsPermanentAndNeverRetried() {
        Test.setMock(HttpCalloutMock.class, TelemetryCalloutMock.failing(404));

        Test.startTest();
        Boolean done = new TelemetryIngestionService().ingest(accountIds(), 1);
        Test.getEventBus().deliver();
        Test.stopTest();

        System.assert(done, '4xx is deterministic; retrying would just fail again');
        System.assertEquals(1, [SELECT COUNT() FROM App_Log__c WHERE Level__c = 'ERROR']);
    }

    @IsTest
    static void unknownAccountKeysAreLoggedAndSkipped() {
        TelemetryUsageDTO stranger = new TelemetryUsageDTO();
        stranger.accountKey = 'BILL-DOES-NOT-EXIST';
        stranger.monthlyActiveUsers = 1;
        stranger.licenseUtilization = 1;
        Test.setMock(
            HttpCalloutMock.class,
            TelemetryCalloutMock.success(new List<TelemetryUsageDTO>{ stranger })
        );

        Test.startTest();
        Boolean done = new TelemetryIngestionService().ingest(accountIds(), 1);
        Test.getEventBus().deliver();
        Test.stopTest();

        System.assert(done);
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Account WHERE Monthly_Active_Users__c != NULL],
            'No account may be updated from an unknown key'
        );
        System.assertEquals(1, [SELECT COUNT() FROM App_Log__c WHERE Level__c = 'WARN']);
    }

    @IsTest
    static void batchIngestsThroughTheSamePipeline() {
        List<Account> accounts = [SELECT Id, Billing_System_Id__c FROM Account];
        List<TelemetryUsageDTO> usages = new List<TelemetryUsageDTO>();
        for (Account account : accounts) {
            TelemetryUsageDTO usage = new TelemetryUsageDTO();
            usage.accountKey = account.Billing_System_Id__c;
            usage.monthlyActiveUsers = 42;
            usage.licenseUtilization = 33;
            usages.add(usage);
        }
        Test.setMock(HttpCalloutMock.class, TelemetryCalloutMock.success(usages));

        Test.startTest();
        Database.executeBatch(new TelemetryIngestionBatch(), TelemetryIngestionScheduler.BATCH_SCOPE);
        Test.stopTest();

        System.assertEquals(
            3,
            [SELECT COUNT() FROM Account WHERE Monthly_Active_Users__c = 42],
            'Batch chunk must land the same updates as the service'
        );
    }

    @IsTest
    static void retryQueueableProcessesItsPage() {
        List<Account> accounts = [SELECT Id, Billing_System_Id__c FROM Account];
        List<TelemetryUsageDTO> usages = new List<TelemetryUsageDTO>();
        for (Account account : accounts) {
            TelemetryUsageDTO usage = new TelemetryUsageDTO();
            usage.accountKey = account.Billing_System_Id__c;
            usage.monthlyActiveUsers = 7;
            usage.licenseUtilization = 12;
            usages.add(usage);
        }
        Test.setMock(HttpCalloutMock.class, TelemetryCalloutMock.success(usages));

        Test.startTest();
        System.enqueueJob(new TelemetryRetryQueueable(accountIds(), 2));
        Test.stopTest();

        System.assertEquals(3, [SELECT COUNT() FROM Account WHERE Monthly_Active_Users__c = 7]);
    }
}
