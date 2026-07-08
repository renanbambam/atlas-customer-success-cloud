/**
 * One account's usage metrics as returned by the telemetry API. Field names
 * match the provider's JSON contract; mapping onto the org's schema happens
 * in TelemetryIngestionService, nowhere else.
 */
public class TelemetryUsageDTO {
    public String accountKey; // the billing system id shared by both systems
    public Integer monthlyActiveUsers;
    public Decimal licenseUtilization; // 0-100
}
