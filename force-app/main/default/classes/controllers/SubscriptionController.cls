/**
 * LWC-facing read model for the subscription list on the account page.
 */
public with sharing class SubscriptionController {
    @AuraEnabled(cacheable=true)
    public static List<Subscription__c> getSubscriptions(Id accountId) {
        try {
            return new SubscriptionSelector().selectByAccountId(accountId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
