/**
 * Base class for all trigger handlers. Routes trigger events to overridable
 * methods and exposes a transaction-scoped bypass API so data migrations and
 * integration jobs can suppress automation deliberately instead of with flags
 * on records.
 */
public virtual class TriggerHandler {
    private static final Set<String> BYPASSED = new Set<String>();

    public void run() {
        if (!Trigger.isExecuting || isBypassed(handlerName())) {
            return;
        }
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
