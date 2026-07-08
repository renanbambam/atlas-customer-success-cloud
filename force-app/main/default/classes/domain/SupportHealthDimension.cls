/**
 * Support: friction in the support channel. Open cases erode the score
 * gradually; escalations erode it fast because they mean the normal process
 * already failed. Deduction caps keep one pathological account from pinning
 * the dimension below zero.
 */
public inherited sharing class SupportHealthDimension implements IHealthDimension {
    private static final Integer OPEN_CASE_PENALTY = 8;
    private static final Integer OPEN_CASE_PENALTY_CAP = 48;
    private static final Integer ESCALATION_PENALTY = 20;
    private static final Integer ESCALATION_PENALTY_CAP = 40;

    public Decimal score(HealthScoreContext context) {
        Integer openPenalty = Math.min(context.openCases * OPEN_CASE_PENALTY, OPEN_CASE_PENALTY_CAP);
        Integer escalationPenalty = Math.min(
            context.escalatedCases90d * ESCALATION_PENALTY,
            ESCALATION_PENALTY_CAP
        );
        return Math.max(0, 100 - openPenalty - escalationPenalty);
    }
}
