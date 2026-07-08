/**
 * Inbound payload contract for POST /atlas/v1/subscriptions. Deliberately a
 * plain DTO: the billing system's vocabulary stops here, and only
 * toSubscription() knows how it maps onto the org's schema.
 */
public class SubscriptionSyncRequest {
    public List<SubscriptionItem> subscriptions;

    public class SubscriptionItem {
        public String externalId;
        public String accountBillingId;
        public String status;
        public String startDate; // ISO-8601 date (yyyy-MM-dd)
        public String endDate;
        public String renewalDate;
        public Boolean autoRenew;

        /** Returns a human-readable problem, or null when the item is processable. */
        public String validate() {
            if (String.isBlank(externalId)) {
                return 'externalId is required';
            }
            if (String.isBlank(accountBillingId)) {
                return 'accountBillingId is required';
            }
            if (String.isBlank(startDate) || String.isBlank(endDate)) {
                return 'startDate and endDate are required';
            }
            try {
                Date.valueOf(startDate);
                Date.valueOf(endDate);
                if (String.isNotBlank(renewalDate)) {
                    Date.valueOf(renewalDate);
                }
            } catch (Exception e) {
                return 'Dates must be ISO-8601 (yyyy-MM-dd)';
            }
            return null;
        }

        public Subscription__c toSubscription(Id accountId) {
            return new Subscription__c(
                External_Id__c = externalId,
                Account__c = accountId,
                Status__c = String.isBlank(status) ? 'Draft' : status,
                Start_Date__c = Date.valueOf(startDate),
                End_Date__c = Date.valueOf(endDate),
                Renewal_Date__c = String.isBlank(renewalDate) ? null : Date.valueOf(renewalDate),
                Auto_Renew__c = autoRenew == true
            );
        }
    }
}
