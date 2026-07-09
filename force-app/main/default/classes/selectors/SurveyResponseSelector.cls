/**
 * All Survey_Response__c reads. NPS aggregation is done in SOQL so the survey
 * volume per account never has to fit in the heap.
 */
public inherited sharing class SurveyResponseSelector {
    /**
     * Per-account NPS raw material: promoter/detractor/total counts inside the
     * window. SYSTEM_MODE by design — Account.NPS__c is a system-maintained
     * rollup, so the aggregate must see every response regardless of the
     * running user's FLS or sharing, exactly like a roll-up summary. The name
     * carries the SystemMode suffix this codebase uses to flag that bypass.
     */
    public Map<Id, NpsAggregate> aggregateNpsByAccountSystemMode(Set<Id> accountIds, Integer windowDays) {
        Date windowStart = Date.today().addDays(-windowDays);
        Map<Id, NpsAggregate> aggregatesByAccount = new Map<Id, NpsAggregate>();
        for (AggregateResult result : [
            SELECT
                Account__c accId,
                COUNT(Id) total,
                SUM(Promoter__c) promoters,
                SUM(Detractor__c) detractors,
                MAX(Response_Date__c) lastResponse
            FROM Survey_Response__c
            WHERE Account__c IN :accountIds AND Type__c = 'NPS' AND Response_Date__c >= :windowStart
            WITH SYSTEM_MODE
            GROUP BY Account__c
        ]) {
            NpsAggregate aggregate = new NpsAggregate();
            aggregate.total = (Integer) result.get('total');
            aggregate.promoters = ((Decimal) result.get('promoters')).intValue();
            aggregate.detractors = ((Decimal) result.get('detractors')).intValue();
            aggregate.lastResponseDate = (Date) result.get('lastResponse');
            aggregatesByAccount.put((Id) result.get('accId'), aggregate);
        }
        return aggregatesByAccount;
    }

    public class NpsAggregate {
        public Integer total = 0;
        public Integer promoters = 0;
        public Integer detractors = 0;
        public Date lastResponseDate;

        public Integer npsScore() {
            if (total == 0) {
                return null;
            }
            Decimal promoterShare = (Decimal) promoters / total;
            Decimal detractorShare = (Decimal) detractors / total;
            return ((promoterShare - detractorShare) * 100).round().intValue();
        }
    }
}
