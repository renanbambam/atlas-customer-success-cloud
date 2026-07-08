@IsTest
private class AtlasSubscriptionRestApiTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createAccounts(2);
    }

    private static void post(String body) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/atlas/v1/subscriptions';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(body);
        RestContext.request = request;
        RestContext.response = new RestResponse();
        AtlasSubscriptionRestApi.upsertSubscriptions();
    }

    private static String payloadFor(String externalId, String billingId, String status) {
        return JSON.serialize(
            new Map<String, Object>{
                'subscriptions' => new List<Object>{
                    new Map<String, Object>{
                        'externalId' => externalId,
                        'accountBillingId' => billingId,
                        'status' => status,
                        'startDate' => '2026-01-01',
                        'endDate' => '2026-12-31',
                        'renewalDate' => '2026-12-31',
                        'autoRenew' => true
                    }
                }
            }
        );
    }

    @IsTest
    static void createsThenUpdatesIdempotently() {
        Account account = [SELECT Billing_System_Id__c FROM Account LIMIT 1];

        Test.startTest();
        post(payloadFor('SUB-BILLING-1', account.Billing_System_Id__c, 'Draft'));
        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('"created"'));

        // Exact replay: same key, must update the same record, not duplicate it.
        post(payloadFor('SUB-BILLING-1', account.Billing_System_Id__c, 'Draft'));
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('"updated"'));
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Subscription__c WHERE External_Id__c = 'SUB-BILLING-1'],
            'Replay must not create a second subscription'
        );
    }

    @IsTest
    static void activeSubscriptionFromBillingOpensRenewalPipeline() {
        Account account = [SELECT Billing_System_Id__c FROM Account LIMIT 1];

        Test.startTest();
        post(payloadFor('SUB-BILLING-2', account.Billing_System_Id__c, 'Active'));
        Test.stopTest();

        Subscription__c subscription = [
            SELECT Id
            FROM Subscription__c
            WHERE External_Id__c = 'SUB-BILLING-2'
        ];
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Opportunity WHERE Subscription__c = :subscription.Id],
            'Activation through the API must drive the same renewal automation as the UI'
        );
    }

    @IsTest
    static void unknownAccountKeyFailsOnlyThatItem() {
        Account account = [SELECT Billing_System_Id__c FROM Account LIMIT 1];
        String body = JSON.serialize(
            new Map<String, Object>{
                'subscriptions' => new List<Object>{
                    new Map<String, Object>{
                        'externalId' => 'SUB-OK',
                        'accountBillingId' => account.Billing_System_Id__c,
                        'status' => 'Draft',
                        'startDate' => '2026-01-01',
                        'endDate' => '2026-12-31'
                    },
                    new Map<String, Object>{
                        'externalId' => 'SUB-ORPHAN',
                        'accountBillingId' => 'BILL-UNKNOWN',
                        'status' => 'Draft',
                        'startDate' => '2026-01-01',
                        'endDate' => '2026-12-31'
                    }
                }
            }
        );

        Test.startTest();
        post(body);
        Test.stopTest();

        System.assertEquals(
            200,
            RestContext.response.statusCode,
            'Partial success is a 200 with per-item results'
        );
        String responseBody = RestContext.response.responseBody.toString();
        System.assert(responseBody.contains('Unknown accountBillingId'), responseBody);
        System.assertEquals(1, [SELECT COUNT() FROM Subscription__c WHERE External_Id__c = 'SUB-OK']);
        System.assertEquals(0, [SELECT COUNT() FROM Subscription__c WHERE External_Id__c = 'SUB-ORPHAN']);
    }

    @IsTest
    static void malformedJsonIsA400() {
        Test.startTest();
        post('{this is not json');
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void emptyPayloadIsA400() {
        Test.startTest();
        post('{"subscriptions": []}');
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void invalidDatesAreRejectedPerItem() {
        Account account = [SELECT Billing_System_Id__c FROM Account LIMIT 1];
        String body = JSON.serialize(
            new Map<String, Object>{
                'subscriptions' => new List<Object>{
                    new Map<String, Object>{
                        'externalId' => 'SUB-BAD-DATE',
                        'accountBillingId' => account.Billing_System_Id__c,
                        'status' => 'Draft',
                        'startDate' => 'not-a-date',
                        'endDate' => '2026-12-31'
                    }
                }
            }
        );

        Test.startTest();
        post(body);
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('ISO-8601'));
        System.assertEquals(0, [SELECT COUNT() FROM Subscription__c WHERE External_Id__c = 'SUB-BAD-DATE']);
    }
}
