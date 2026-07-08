/**
 * Keeps Account.NPS__c current whenever survey responses change, including
 * deletes and undeletes (GDPR erasure of a detractor's response must move
 * the aggregate too).
 */
public inherited sharing class SurveyResponseTriggerHandler extends AtlasTriggerHandler {
    private final SurveyService service = new SurveyService();

    protected override void afterInsert(List<SObject> newRecords) {
        service.recalculateAccountNps(accountIdsFrom(newRecords));
    }

    protected override void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldById) {
        // A response can move between accounts on data fixes; refresh both sides.
        Set<Id> accountIds = accountIdsFrom(newRecords);
        accountIds.addAll(accountIdsFrom(oldById.values()));
        service.recalculateAccountNps(accountIds);
    }

    protected override void afterDelete(List<SObject> oldRecords) {
        service.recalculateAccountNps(accountIdsFrom(oldRecords));
    }

    protected override void afterUndelete(List<SObject> newRecords) {
        service.recalculateAccountNps(accountIdsFrom(newRecords));
    }

    private Set<Id> accountIdsFrom(List<SObject> records) {
        Set<Id> accountIds = new Set<Id>();
        for (Survey_Response__c response : (List<Survey_Response__c>) records) {
            if (response.Type__c == 'NPS' && response.Account__c != null) {
                accountIds.add(response.Account__c);
            }
        }
        return accountIds;
    }
}
