@IsTest
private class SurveyResponseTriggerTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createAccounts(1);
    }

    @IsTest
    static void npsResponsesRollUpToAccountScore() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        // 2 promoters (10, 9), 1 passive (8), 1 detractor (2) => (50% - 25%) = 25
        TestDataFactory.createNpsResponses(account, new List<Integer>{ 10, 9, 8, 2 });

        account = [SELECT NPS__c FROM Account WHERE Id = :account.Id];
        System.assertEquals(25, account.NPS__c);
    }

    @IsTest
    static void deletingAResponseRecalculatesTheAggregate() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        List<Survey_Response__c> responses = TestDataFactory.createNpsResponses(
            account,
            new List<Integer>{ 10, 0 }
        );
        System.assertEquals(0, [SELECT NPS__c FROM Account WHERE Id = :account.Id].NPS__c);

        delete responses[1]; // remove the detractor

        System.assertEquals(100, [SELECT NPS__c FROM Account WHERE Id = :account.Id].NPS__c);
    }

    @IsTest
    static void deletingTheLastResponseClearsTheScore() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        List<Survey_Response__c> responses = TestDataFactory.createNpsResponses(
            account,
            new List<Integer>{ 10 }
        );

        delete responses;

        System.assertEquals(null, [SELECT NPS__c FROM Account WHERE Id = :account.Id].NPS__c);
    }

    @IsTest
    static void csatResponsesDoNotTouchNps() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        insert new Survey_Response__c(
            Account__c = account.Id,
            Type__c = 'CSAT',
            Score__c = 5,
            Response_Date__c = Date.today()
        );

        System.assertEquals(null, [SELECT NPS__c FROM Account WHERE Id = :account.Id].NPS__c);
    }

    @IsTest
    static void outOfRangeScoreIsRejectedByValidationRule() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Survey_Response__c bad = new Survey_Response__c(
            Account__c = account.Id,
            Type__c = 'NPS',
            Score__c = 11,
            Response_Date__c = Date.today()
        );
        Database.SaveResult result = Database.insert(bad, false);
        System.assert(!result.isSuccess(), 'NPS above 10 must be rejected');
    }

    @IsTest
    static void bulkInsertRecalculatesOnce() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        List<Integer> scores = new List<Integer>();
        for (Integer i = 0; i < 200; i++) {
            scores.add(10); // all promoters
        }
        Test.startTest();
        TestDataFactory.createNpsResponses(account, scores);
        Test.stopTest();

        System.assertEquals(100, [SELECT NPS__c FROM Account WHERE Id = :account.Id].NPS__c);
    }
}
