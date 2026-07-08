/**
 * Subscription lifecycle orchestration: keeps the renewal pipeline aligned
 * with subscription state (ADR-0003) and performs the idempotent upsert used
 * by the billing sync API (ADR-0006).
 */
public inherited sharing class SubscriptionService {
    private static final String SOURCE = 'SubscriptionService';
    private static final String STAGE_OPEN = 'Prospecting';
    private static final String STAGE_CLOSED_LOST = 'Closed Lost';

    private final SubscriptionSelector subscriptionSelector = new SubscriptionSelector();
    private final OpportunitySelector opportunitySelector = new OpportunitySelector();
    private final AccountSelector accountSelector = new AccountSelector();

    /**
     * Trigger entry point (after insert / after update). Creates the renewal
     * opportunity when a subscription activates, realigns its close date when
     * the renewal date moves, and closes it lost when the customer churns.
     */
    public void syncRenewalOpportunities(
        List<Subscription__c> subscriptions,
        Map<Id, Subscription__c> oldById
    ) {
        Set<Id> activatedIds = new Set<Id>();
        Set<Id> realignIds = new Set<Id>();
        Set<Id> churnedIds = new Set<Id>();

        for (Subscription__c subscription : subscriptions) {
            Subscription__c previous = oldById == null ? null : oldById.get(subscription.Id);
            Boolean wasActive = previous != null && previous.Status__c == 'Active';
            if (subscription.Status__c == 'Active' && !wasActive) {
                activatedIds.add(subscription.Id);
            } else if (
                subscription.Status__c == 'Active' &&
                previous != null &&
                subscription.Renewal_Date__c != previous.Renewal_Date__c
            ) {
                realignIds.add(subscription.Id);
            } else if (subscription.Status__c == 'Churned' && wasActive) {
                churnedIds.add(subscription.Id);
            }
        }
        if (activatedIds.isEmpty() && realignIds.isEmpty() && churnedIds.isEmpty()) {
            return;
        }

        Set<Id> allIds = new Set<Id>();
        allIds.addAll(activatedIds);
        allIds.addAll(realignIds);
        allIds.addAll(churnedIds);

        Map<Id, Subscription__c> subscriptionsById = new Map<Id, Subscription__c>(
            subscriptionSelector.selectByIdWithAccount(allIds)
        );
        Map<Id, Opportunity> openRenewalBySubscription = new Map<Id, Opportunity>();
        for (Opportunity renewal : opportunitySelector.selectOpenRenewalsBySubscriptionId(allIds)) {
            openRenewalBySubscription.put(renewal.Subscription__c, renewal);
        }

        List<Opportunity> toInsert = new List<Opportunity>();
        List<Opportunity> toUpdate = new List<Opportunity>();

        for (Id subscriptionId : activatedIds) {
            Subscription__c subscription = subscriptionsById.get(subscriptionId);
            // Idempotency guard: a reactivation replay must not duplicate the pipeline.
            if (subscription == null || openRenewalBySubscription.containsKey(subscriptionId)) {
                continue;
            }
            toInsert.add(buildRenewalOpportunity(subscription));
        }
        for (Id subscriptionId : realignIds) {
            Subscription__c subscription = subscriptionsById.get(subscriptionId);
            Opportunity renewal = openRenewalBySubscription.get(subscriptionId);
            if (subscription == null || subscription.Renewal_Date__c == null) {
                continue;
            }
            if (renewal == null) {
                // The renewal was closed or deleted out-of-band; restore the pipeline.
                toInsert.add(buildRenewalOpportunity(subscription));
            } else {
                renewal.CloseDate = subscription.Renewal_Date__c;
                toUpdate.add(renewal);
            }
        }
        for (Id subscriptionId : churnedIds) {
            Opportunity renewal = openRenewalBySubscription.get(subscriptionId);
            if (renewal != null) {
                renewal.StageName = STAGE_CLOSED_LOST;
                toUpdate.add(renewal);
            }
        }

        UnitOfWork uow = new UnitOfWork(new List<SObjectType>{ Opportunity.SObjectType });
        uow.registerNew(toInsert);
        uow.registerDirty(toUpdate);
        uow.commitWork();
    }

    /**
     * Idempotent upsert keyed by External_Id__c, called by the billing sync
     * REST resource. Returns one result per item; a bad item never blocks the
     * rest of the payload (allOrNone=false).
     */
    public List<SubscriptionSyncResult> upsertFromBilling(
        List<SubscriptionSyncRequest.SubscriptionItem> items
    ) {
        List<SubscriptionSyncResult> results = new List<SubscriptionSyncResult>();

        Set<String> billingIds = new Set<String>();
        for (SubscriptionSyncRequest.SubscriptionItem item : items) {
            if (String.isNotBlank(item.accountBillingId)) {
                billingIds.add(item.accountBillingId);
            }
        }
        Map<String, Id> accountIdByBillingId = new Map<String, Id>();
        for (Account account : accountSelector.selectByBillingSystemIdSystemMode(billingIds)) {
            accountIdByBillingId.put(account.Billing_System_Id__c, account.Id);
        }

        List<Subscription__c> toUpsert = new List<Subscription__c>();
        List<SubscriptionSyncResult> pendingResults = new List<SubscriptionSyncResult>();

        for (SubscriptionSyncRequest.SubscriptionItem item : items) {
            String validationError = item.validate();
            if (validationError == null && !accountIdByBillingId.containsKey(item.accountBillingId)) {
                validationError = 'Unknown accountBillingId: ' + item.accountBillingId;
            }
            if (validationError != null) {
                results.add(SubscriptionSyncResult.error(item.externalId, validationError));
                continue;
            }
            toUpsert.add(item.toSubscription(accountIdByBillingId.get(item.accountBillingId)));
            pendingResults.add(SubscriptionSyncResult.pending(item.externalId));
        }

        if (!toUpsert.isEmpty()) {
            // Defense in depth on top of the integration user's minimal
            // permission set (ADR-0005): strip anything the user cannot write.
            List<Subscription__c> sanitized = (List<Subscription__c>) Security.stripInaccessible(
                    AccessType.UPSERTABLE,
                    toUpsert
                )
                .getRecords();
            // External id must survive stripping or the upsert key is gone.
            for (Integer i = 0; i < sanitized.size(); i++) {
                sanitized[i].External_Id__c = toUpsert[i].External_Id__c;
            }
            List<Database.UpsertResult> upsertResults = Database.upsert(
                sanitized,
                Subscription__c.External_Id__c,
                false,
                System.AccessLevel.SYSTEM_MODE
            );
            for (Integer i = 0; i < upsertResults.size(); i++) {
                SubscriptionSyncResult pending = pendingResults[i];
                if (upsertResults[i].isSuccess()) {
                    pending.outcome = upsertResults[i].isCreated() ? 'created' : 'updated';
                } else {
                    pending.outcome = 'error';
                    pending.message = upsertResults[i].getErrors()[0].getMessage();
                    Logger.error(SOURCE, 'Billing sync failed for ' + pending.externalId, pending.message);
                }
            }
        }
        results.addAll(pendingResults);
        Logger.flush();
        return results;
    }

    private Opportunity buildRenewalOpportunity(Subscription__c subscription) {
        Date closeDate = subscription.Renewal_Date__c != null
            ? subscription.Renewal_Date__c
            : subscription.End_Date__c;
        return new Opportunity(
            Name = subscription.Account__r.Name + ' - Renewal ' + closeDate.year(),
            AccountId = subscription.Account__c,
            Subscription__c = subscription.Id,
            RecordTypeId = opportunitySelector.renewalRecordTypeId(),
            StageName = STAGE_OPEN,
            CloseDate = closeDate,
            Amount = subscription.Total_ARR__c
        );
    }
}
