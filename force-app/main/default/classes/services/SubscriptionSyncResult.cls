/**
 * Per-item outcome returned by the billing sync API: 'created', 'updated' or
 * 'error' plus a message. The billing system replays 'error' items after
 * fixing them; replays are safe because the upsert is keyed (ADR-0006).
 */
public class SubscriptionSyncResult {
    public String externalId;
    public String outcome;
    public String message;

    public static SubscriptionSyncResult error(String externalId, String message) {
        SubscriptionSyncResult result = new SubscriptionSyncResult();
        result.externalId = externalId;
        result.outcome = 'error';
        result.message = message;
        return result;
    }

    public static SubscriptionSyncResult pending(String externalId) {
        SubscriptionSyncResult result = new SubscriptionSyncResult();
        result.externalId = externalId;
        return result;
    }
}
