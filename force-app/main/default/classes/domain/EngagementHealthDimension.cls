/**
 * Engagement: is the customer still talking to us, and how do they feel.
 * NPS (-100..100) maps linearly onto 0..100; silence beyond the survey window
 * yields null so the weight shifts to dimensions that do have signal.
 */
public inherited sharing class EngagementHealthDimension implements IHealthDimension {
    public Decimal score(HealthScoreContext context) {
        if (context.npsScore == null) {
            return null;
        }
        Decimal mapped = (context.npsScore + 100) / 2.0;
        if (mapped < 0) {
            return 0;
        }
        return mapped > 100 ? 100 : mapped;
    }
}
