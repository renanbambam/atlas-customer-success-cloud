/**
 * Adoption: how much of what the customer bought is actually used.
 * License utilization is already a 0-100 percentage; a customer with licenses
 * on the shelf is the classic leading indicator of churn.
 */
public inherited sharing class AdoptionHealthDimension implements IHealthDimension {
    public Decimal score(HealthScoreContext context) {
        if (context.licenseUtilization == null) {
            return null;
        }
        Decimal utilization = context.licenseUtilization;
        if (utilization < 0) {
            return 0;
        }
        return utilization > 100 ? 100 : utilization;
    }
}
