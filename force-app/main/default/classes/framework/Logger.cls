/**
 * Application logging facade. Entries are buffered per transaction and
 * published as Log_Event__e (publish-immediately) so they survive rollback of
 * the business transaction — see ADR-0007. A subscriber trigger persists the
 * events to App_Log__c.
 */
public inherited sharing class Logger {
    private static final Integer TEXT_LIMIT = 32768;
    private static final List<Log_Event__e> BUFFER = new List<Log_Event__e>();

    public static void error(String source, String message, Exception cause) {
        add(
            'ERROR',
            source,
            message + (cause == null ? '' : ': ' + cause.getMessage()),
            null,
            cause == null ? null : cause.getStackTraceString()
        );
    }

    public static void error(String source, String message, String referenceId) {
        add('ERROR', source, message, referenceId, null);
    }

    public static void warn(String source, String message, String referenceId) {
        add('WARN', source, message, referenceId, null);
    }

    public static void info(String source, String message, String referenceId) {
        add('INFO', source, message, referenceId, null);
    }

    /** Publishes the buffered entries. Call once per transaction, in a finally block. */
    public static void flush() {
        if (BUFFER.isEmpty()) {
            return;
        }
        EventBus.publish(BUFFER);
        BUFFER.clear();
    }

    @TestVisible
    private static Integer bufferSize() {
        return BUFFER.size();
    }

    private static void add(
        String level,
        String source,
        String message,
        String referenceId,
        String stackTrace
    ) {
        BUFFER.add(
            new Log_Event__e(
                Level__c = level,
                Source__c = source == null ? null : source.abbreviate(120),
                Message__c = message == null ? null : message.abbreviate(TEXT_LIMIT),
                Reference_Id__c = referenceId == null ? null : referenceId.abbreviate(64),
                Stack_Trace__c = stackTrace == null ? null : stackTrace.abbreviate(TEXT_LIMIT)
            )
        );
    }
}
