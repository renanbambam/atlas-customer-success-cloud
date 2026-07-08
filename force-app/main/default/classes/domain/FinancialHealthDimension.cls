/**
 * Financial: renewal exposure. Auto-renew removes most of the risk; without
 * it, risk rises as the renewal date approaches — the closer the date, the
 * less runway the CSM has to fix problems before the commercial conversation.
 */
public inherited sharing class FinancialHealthDimension implements IHealthDimension {
    public Decimal score(HealthScoreContext context) {
        if (context.daysToNearestRenewal == null) {
            return null;
        }
        if (context.autoRenew) {
            return 90;
        }
        Integer days = context.daysToNearestRenewal;
        if (days > 180) {
            return 80;
        }
        if (days > 90) {
            return 65;
        }
        if (days > 30) {
            return 50;
        }
        return 35;
    }
}
