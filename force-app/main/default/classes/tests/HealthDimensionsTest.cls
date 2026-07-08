/**
 * Pure-function tests for the dimension strategies: exactly the kind of
 * business math that must be verifiable without a single DML statement.
 */
@IsTest
private class HealthDimensionsTest {
    @IsTest
    static void adoptionMapsUtilizationAndClampsBounds() {
        AdoptionHealthDimension dimension = new AdoptionHealthDimension();
        HealthScoreContext context = new HealthScoreContext();

        System.assertEquals(null, dimension.score(context), 'No telemetry means no signal');

        context.licenseUtilization = 73;
        System.assertEquals(73, dimension.score(context));

        context.licenseUtilization = 140;
        System.assertEquals(100, dimension.score(context), 'Over-provisioned usage clamps at 100');

        context.licenseUtilization = -5;
        System.assertEquals(0, dimension.score(context));
    }

    @IsTest
    static void supportPenalizesOpenCasesAndEscalationsWithCaps() {
        SupportHealthDimension dimension = new SupportHealthDimension();
        HealthScoreContext context = new HealthScoreContext();

        System.assertEquals(100, dimension.score(context), 'No cases, perfect support health');

        context.openCases = 2;
        System.assertEquals(84, dimension.score(context));

        context.openCases = 100;
        context.escalatedCases90d = 100;
        System.assertEquals(
            12,
            dimension.score(context),
            'Caps must hold: 100 - 48 - 40 even for pathological accounts'
        );
    }

    @IsTest
    static void engagementMapsNpsLinearly() {
        EngagementHealthDimension dimension = new EngagementHealthDimension();
        HealthScoreContext context = new HealthScoreContext();

        System.assertEquals(null, dimension.score(context), 'Silence is absence of signal, not zero');

        context.npsScore = -100;
        System.assertEquals(0, dimension.score(context));

        context.npsScore = 0;
        System.assertEquals(50, dimension.score(context));

        context.npsScore = 100;
        System.assertEquals(100, dimension.score(context));
    }

    @IsTest
    static void financialReflectsRenewalRunwayAndAutoRenew() {
        FinancialHealthDimension dimension = new FinancialHealthDimension();
        HealthScoreContext context = new HealthScoreContext();

        System.assertEquals(null, dimension.score(context), 'No active subscription, no financial signal');

        context.daysToNearestRenewal = 15;
        context.autoRenew = true;
        System.assertEquals(90, dimension.score(context), 'Auto-renew neutralizes date pressure');

        context.autoRenew = false;
        System.assertEquals(35, dimension.score(context), 'Imminent manual renewal is the risky case');

        context.daysToNearestRenewal = 400;
        System.assertEquals(80, dimension.score(context));
    }
}
