/**
 * Subscription state rules. Pure in-memory logic invoked from the before
 * phase of the trigger; violations are reported with addError so one bad row
 * never rolls back a bulk load.
 *
 * State machine: Draft -> Active | Expired; Active -> Renewed | Churned | Expired.
 * Renewed, Churned and Expired are terminal.
 */
public inherited sharing class SubscriptionDomain {
    private static final Map<String, Set<String>> ALLOWED_TRANSITIONS = new Map<String, Set<String>>{
        'Draft' => new Set<String>{ 'Active', 'Expired' },
        'Active' => new Set<String>{ 'Renewed', 'Churned', 'Expired' },
        'Renewed' => new Set<String>(),
        'Churned' => new Set<String>(),
        'Expired' => new Set<String>()
    };

    public void applyDefaults(List<Subscription__c> subscriptions) {
        for (Subscription__c subscription : subscriptions) {
            // Renewal Date drives the pipeline; defaulting to the term end is
            // the correct answer for the overwhelming majority of contracts.
            if (subscription.Status__c == 'Active' && subscription.Renewal_Date__c == null) {
                subscription.Renewal_Date__c = subscription.End_Date__c;
            }
        }
    }

    public void validateTransitions(List<Subscription__c> updated, Map<Id, Subscription__c> oldById) {
        for (Subscription__c subscription : updated) {
            String previousStatus = oldById.get(subscription.Id).Status__c;
            String newStatus = subscription.Status__c;
            if (previousStatus == newStatus) {
                continue;
            }
            Set<String> allowed = ALLOWED_TRANSITIONS.get(previousStatus);
            if (allowed == null || !allowed.contains(newStatus)) {
                subscription.Status__c.addError(
                    'Invalid status transition: ' + previousStatus + ' → ' + newStatus
                );
            }
        }
    }
}
