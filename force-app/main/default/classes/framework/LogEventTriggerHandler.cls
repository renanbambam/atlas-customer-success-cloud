/**
 * Persists Log_Event__e to App_Log__c. Runs as the Automated Process user, so
 * DML is deliberately SYSTEM_MODE (ADR-0005) and allOrNone=false: losing one
 * malformed entry must never block the rest of the batch.
 */
public without sharing class LogEventTriggerHandler extends AtlasTriggerHandler {
    protected override void afterInsert(List<SObject> newRecords) {
        List<App_Log__c> logs = new List<App_Log__c>();
        for (Log_Event__e event : (List<Log_Event__e>) newRecords) {
            logs.add(
                new App_Log__c(
                    Level__c = event.Level__c,
                    Source__c = event.Source__c,
                    Message__c = event.Message__c,
                    Reference_Id__c = event.Reference_Id__c,
                    Stack_Trace__c = event.Stack_Trace__c
                )
            );
        }
        Database.insert(logs, false, System.AccessLevel.SYSTEM_MODE);
    }
}
