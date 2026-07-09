/**
 * Keeps Account.NPS__c aligned with the survey responses inside the rolling
 * window. Cheap enough to run synchronously in the survey trigger; the full
 * health recalculation stays in the nightly batch to keep save time and the
 * transaction's governor budget low.
 */
public inherited sharing class SurveyService {
    private final SurveyResponseSelector surveySelector = new SurveyResponseSelector();

    public void recalculateAccountNps(Set<Id> accountIds) {
        if (accountIds.isEmpty()) {
            return;
        }
        Map<Id, SurveyResponseSelector.NpsAggregate> aggregatesByAccount = surveySelector.aggregateNpsByAccountSystemMode(
            accountIds,
            AtlasSettings.npsWindowDays()
        );

        List<Account> updates = new List<Account>();
        for (Id accountId : accountIds) {
            SurveyResponseSelector.NpsAggregate aggregate = aggregatesByAccount.get(accountId);
            updates.add(
                new Account(Id = accountId, NPS__c = aggregate == null ? null : aggregate.npsScore())
            );
        }

        UnitOfWork uow = new UnitOfWork(new List<SObjectType>{ Account.SObjectType });
        uow.registerDirty(updates);
        uow.commitWork();
    }
}
