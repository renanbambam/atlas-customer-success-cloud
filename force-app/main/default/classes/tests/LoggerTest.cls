@IsTest
private class LoggerTest {
    @IsTest
    static void flushPublishesEventsAndSubscriberPersistsAppLog() {
        Test.startTest();
        Logger.error('LoggerTest', 'Something broke', 'REF-001');
        Logger.warn('LoggerTest', 'Something looks off', null);
        System.assertEquals(2, Logger.bufferSize(), 'Entries should buffer until flush');
        Logger.flush();
        Test.getEventBus().deliver();
        Test.stopTest();

        List<App_Log__c> logs = [
            SELECT Level__c, Message__c, Source__c, Reference_Id__c
            FROM App_Log__c
            ORDER BY Level__c
        ];
        System.assertEquals(2, logs.size(), 'Subscriber trigger should persist both entries');
        System.assertEquals('ERROR', logs[0].Level__c);
        System.assertEquals('REF-001', logs[0].Reference_Id__c);
        System.assertEquals('LoggerTest', logs[0].Source__c);
    }

    @IsTest
    static void oversizedMessagesAreTruncatedNotDropped() {
        String huge = 'x'.repeat(40000);
        Test.startTest();
        Logger.error('LoggerTest', huge, (String) null);
        Logger.flush();
        Test.getEventBus().deliver();
        Test.stopTest();

        List<App_Log__c> logs = [SELECT Message__c FROM App_Log__c];
        System.assertEquals(1, logs.size());
        System.assert(logs[0].Message__c.length() <= 32768, 'Message must fit the field');
    }

    @IsTest
    static void flushWithEmptyBufferIsANoOp() {
        Test.startTest();
        Logger.flush();
        Test.getEventBus().deliver();
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM App_Log__c]);
    }
}
