/**
 * Typed access to Atlas_Setting__mdt with safe fallbacks, so a missing or
 * partially filled metadata record degrades to sane defaults instead of a
 * null pointer in an async job.
 */
public inherited sharing class AtlasSettings {
    private static final Integer DEFAULT_MAX_ATTEMPTS = 3;
    private static final Integer DEFAULT_TIMEOUT_MS = 30000;
    private static final Integer DEFAULT_RETENTION_MONTHS = 18;
    private static final Integer DEFAULT_NPS_WINDOW_DAYS = 180;

    @TestVisible
    private static Atlas_Setting__mdt testOverride;

    public static Integer maxCalloutAttempts() {
        Atlas_Setting__mdt record = instance();
        return record == null ||
            record.Max_Callout_Attempts__c == null
            ? DEFAULT_MAX_ATTEMPTS
            : record.Max_Callout_Attempts__c.intValue();
    }

    public static Integer calloutTimeoutMs() {
        Atlas_Setting__mdt record = instance();
        return record == null ||
            record.Callout_Timeout_Ms__c == null
            ? DEFAULT_TIMEOUT_MS
            : record.Callout_Timeout_Ms__c.intValue();
    }

    public static Integer snapshotRetentionMonths() {
        Atlas_Setting__mdt record = instance();
        return record == null ||
            record.Snapshot_Retention_Months__c == null
            ? DEFAULT_RETENTION_MONTHS
            : record.Snapshot_Retention_Months__c.intValue();
    }

    public static Integer npsWindowDays() {
        Atlas_Setting__mdt record = instance();
        return record == null ||
            record.NPS_Window_Days__c == null
            ? DEFAULT_NPS_WINDOW_DAYS
            : record.NPS_Window_Days__c.intValue();
    }

    private static Atlas_Setting__mdt instance() {
        return testOverride != null ? testOverride : Atlas_Setting__mdt.getInstance('Default');
    }
}
