/**
 * Routes Subscription__c trigger events: state rules in the before phase,
 * renewal pipeline sync in the after phase. No logic lives here beyond
 * casting and delegation.
 */
public inherited sharing class SubscriptionTriggerHandler extends TriggerHandler {
    private final SubscriptionDomain domain = new SubscriptionDomain();
    private final SubscriptionService service = new SubscriptionService();

    protected override void beforeInsert(List<SObject> newRecords) {
        domain.applyDefaults((List<Subscription__c>) newRecords);
    }

    protected override void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldById) {
        List<Subscription__c> subscriptions = (List<Subscription__c>) newRecords;
        domain.applyDefaults(subscriptions);
        domain.validateTransitions(subscriptions, (Map<Id, Subscription__c>) oldById);
    }

    protected override void afterInsert(List<SObject> newRecords) {
        service.syncRenewalOpportunities((List<Subscription__c>) newRecords, null);
    }

    protected override void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldById) {
        service.syncRenewalOpportunities(
            (List<Subscription__c>) newRecords,
            (Map<Id, Subscription__c>) oldById
        );
    }
}
