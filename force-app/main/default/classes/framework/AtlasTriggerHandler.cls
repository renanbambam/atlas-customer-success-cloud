/**
 * Base class for all Atlas trigger handlers. Routes trigger events to
 * overridable methods, guards against a handler re-entering itself, and
 * exposes a transaction-scoped bypass API so data migrations and integration
 * jobs can suppress automation deliberately instead of with flags on records.
 *
 * Deliberately prefixed: a class literally named "TriggerHandler" is the most
 * common collision in orgs that host more than one codebase.
 */
public virtual class AtlasTriggerHandler {
    private static final Set<String> BYPASSED = new Set<String>();
    // Handlers currently on the call stack. If a handler's own DML re-fires its
    // trigger synchronously, the nested invocation is skipped, so self-recursion
    // can't run away; the name is cleared once the outer invocation returns, so
    // separate top-level trigger batches in the same transaction still run.
    private static final Set<String> IN_PROGRESS = new Set<String>();

    public void run() {
        String handler = handlerName();
        if (!Trigger.isExecuting || isBypassed(handler) || IN_PROGRESS.contains(handler)) {
            return;
        }
        IN_PROGRESS.add(handler);
        try {
            dispatch();
        } finally {
            IN_PROGRESS.remove(handler);
        }
    }

    private void dispatch() {
        switch on Trigger.operationType {
            when BEFORE_INSERT {
                beforeInsert(Trigger.new);
            }
            when BEFORE_UPDATE {
                beforeUpdate(Trigger.new, Trigger.oldMap);
            }
            when BEFORE_DELETE {
                beforeDelete(Trigger.old);
            }
            when AFTER_INSERT {
                afterInsert(Trigger.new);
            }
            when AFTER_UPDATE {
                afterUpdate(Trigger.new, Trigger.oldMap);
            }
            when AFTER_DELETE {
                afterDelete(Trigger.old);
            }
            when AFTER_UNDELETE {
                afterUndelete(Trigger.new);
            }
        }
    }

    public static void bypass(String handlerName) {
        BYPASSED.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        BYPASSED.remove(handlerName);
    }

    public static Boolean isBypassed(String handlerName) {
        return BYPASSED.contains(handlerName);
    }

    protected virtual void beforeInsert(List<SObject> newRecords) {
    }

    protected virtual void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldById) {
    }

    protected virtual void beforeDelete(List<SObject> oldRecords) {
    }

    protected virtual void afterInsert(List<SObject> newRecords) {
    }

    protected virtual void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldById) {
    }

    protected virtual void afterDelete(List<SObject> oldRecords) {
    }

    protected virtual void afterUndelete(List<SObject> newRecords) {
    }

    // String.valueOf on an instance yields "ClassName:[...]"; cheaper than a
    // describe call and stable enough for a transaction-scoped registry.
    private String handlerName() {
        return String.valueOf(this).substringBefore(':');
    }
}
