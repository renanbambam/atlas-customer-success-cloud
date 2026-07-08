trigger SurveyResponseTrigger on Survey_Response__c(
    after insert,
    after update,
    after delete,
    after undelete
) {
    new SurveyResponseTriggerHandler().run();
}
