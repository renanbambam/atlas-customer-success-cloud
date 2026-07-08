/**
 * POST /services/apexrest/atlas/v1/subscriptions
 *
 * Inbound billing sync (ADR-0006). Idempotent: the upsert is keyed by the
 * billing system's own subscription id, so at-least-once delivery and replays
 * are safe. Response contract:
 *   200 — payload processed; body carries one result per item
 *   400 — unparseable or empty payload
 *   500 — unexpected fault (logged with a reference id)
 */
@RestResource(urlMapping='/atlas/v1/subscriptions')
global with sharing class AtlasSubscriptionRestApi {
    private static final String SOURCE = 'AtlasSubscriptionRestApi';

    @HttpPost
    global static void upsertSubscriptions() {
        RestResponse response = RestContext.response;
        response.addHeader('Content-Type', 'application/json');

        SubscriptionSyncRequest payload;
        try {
            payload = (SubscriptionSyncRequest) JSON.deserializeStrict(
                RestContext.request.requestBody.toString(),
                SubscriptionSyncRequest.class
            );
        } catch (Exception e) {
            response.statusCode = 400;
            response.responseBody = Blob.valueOf(
                JSON.serialize(new Map<String, String>{ 'error' => 'Malformed JSON: ' + e.getMessage() })
            );
            return;
        }
        if (payload == null || payload.subscriptions == null || payload.subscriptions.isEmpty()) {
            response.statusCode = 400;
            response.responseBody = Blob.valueOf(
                JSON.serialize(
                    new Map<String, String>{ 'error' => 'Payload must contain a subscriptions array' }
                )
            );
            return;
        }

        try {
            List<SubscriptionSyncResult> results = new SubscriptionService()
                .upsertFromBilling(payload.subscriptions);
            response.statusCode = 200;
            response.responseBody = Blob.valueOf(
                JSON.serialize(new Map<String, Object>{ 'results' => results })
            );
        } catch (Exception e) {
            String referenceId = String.valueOf(Crypto.getRandomInteger());
            Logger.error(SOURCE, 'Unexpected fault (' + referenceId + ')', e);
            Logger.flush();
            response.statusCode = 500;
            response.responseBody = Blob.valueOf(
                JSON.serialize(
                    new Map<String, String>{ 'error' => 'Internal error', 'referenceId' => referenceId }
                )
            );
        }
    }
}
