/**
 * Strategy contract for one health score dimension.
 *
 * Implementations must be pure functions: no SOQL, no DML, no callouts — the
 * service pre-loads everything into the context. Return a value between 0 and
 * 100, or null when the dimension has no signal for this account (the service
 * then renormalizes the remaining weights instead of punishing missing data).
 */
public interface IHealthDimension {
    Decimal score(HealthScoreContext context);
}
