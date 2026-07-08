/**
 * Immutable-by-convention snapshot of everything a health dimension may look
 * at for one account. The service builds these in bulk BEFORE any dimension
 * runs; dimensions are pure functions over this context and never query.
 */
public inherited sharing class HealthScoreContext {
    public Id accountId;

    // Adoption signals (from telemetry ingestion)
    public Decimal licenseUtilization; // 0-100, null when telemetry never arrived
    public Integer monthlyActiveUsers;

    // Support signals
    public Integer openCases = 0;
    public Integer escalatedCases90d = 0;

    // Engagement signals
    public Integer npsScore; // -100..100, null when no NPS response in window
    public Date lastSurveyDate;

    // Financial signals
    public Integer daysToNearestRenewal; // null when no active subscription
    public Boolean autoRenew = false;
    public Decimal totalArr = 0;

    // Prior state, for trend and escalation detection
    public Decimal previousScore;
    public String previousRisk;
}
