/**
 * Write side of the data access layer: every DML statement in the application
 * goes through here. Callers register records; commitWork() executes DML in
 * the SObjectType order given at construction, inside a savepoint, honoring
 * the access level chosen when the unit was created.
 *
 * The default is USER_MODE. SYSTEM_MODE construction is reserved for the
 * paths enumerated in ADR-0005.
 */
public inherited sharing class UnitOfWork {
    private final List<SObjectType> dmlOrder;
    private final System.AccessLevel accessLevel;
    private final Map<SObjectType, List<SObject>> newRecords = new Map<SObjectType, List<SObject>>();
    private final Map<SObjectType, Map<Id, SObject>> dirtyRecords = new Map<SObjectType, Map<Id, SObject>>();
    private final Map<SObjectType, Map<Id, SObject>> deletedRecords = new Map<SObjectType, Map<Id, SObject>>();

    public UnitOfWork(List<SObjectType> dmlOrder) {
        this(dmlOrder, System.AccessLevel.USER_MODE);
    }

    public UnitOfWork(List<SObjectType> dmlOrder, System.AccessLevel accessLevel) {
        this.dmlOrder = dmlOrder;
        this.accessLevel = accessLevel;
        for (SObjectType sObjType : dmlOrder) {
            newRecords.put(sObjType, new List<SObject>());
            dirtyRecords.put(sObjType, new Map<Id, SObject>());
            deletedRecords.put(sObjType, new Map<Id, SObject>());
        }
    }

    public void registerNew(SObject record) {
        requireKnownType(record);
        newRecords.get(record.getSObjectType()).add(record);
    }

    public void registerNew(List<SObject> records) {
        for (SObject record : records) {
            registerNew(record);
        }
    }

    public void registerDirty(SObject record) {
        requireKnownType(record);
        dirtyRecords.get(record.getSObjectType()).put(record.Id, record);
    }

    public void registerDirty(List<SObject> records) {
        for (SObject record : records) {
            registerDirty(record);
        }
    }

    public void registerDeleted(SObject record) {
        requireKnownType(record);
        deletedRecords.get(record.getSObjectType()).put(record.Id, record);
    }

    public void registerDeleted(List<SObject> records) {
        for (SObject record : records) {
            registerDeleted(record);
        }
    }

    public void commitWork() {
        Savepoint sp = Database.setSavepoint();
        try {
            for (SObjectType sObjType : dmlOrder) {
                if (!newRecords.get(sObjType).isEmpty()) {
                    Database.insert(newRecords.get(sObjType), true, accessLevel);
                }
            }
            for (SObjectType sObjType : dmlOrder) {
                if (!dirtyRecords.get(sObjType).isEmpty()) {
                    Database.update(dirtyRecords.get(sObjType).values(), true, accessLevel);
                }
            }
            // Deletes run in reverse order so children go before parents.
            for (Integer i = dmlOrder.size() - 1; i >= 0; i--) {
                SObjectType sObjType = dmlOrder[i];
                if (!deletedRecords.get(sObjType).isEmpty()) {
                    Database.delete(deletedRecords.get(sObjType).values(), true, accessLevel);
                }
            }
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
        clear();
    }

    private void clear() {
        for (SObjectType sObjType : dmlOrder) {
            newRecords.get(sObjType).clear();
            dirtyRecords.get(sObjType).clear();
            deletedRecords.get(sObjType).clear();
        }
    }

    private void requireKnownType(SObject record) {
        if (!newRecords.containsKey(record.getSObjectType())) {
            throw new UnitOfWorkException(
                'SObjectType ' +
                    record.getSObjectType() +
                    ' was not registered in the DML order of this UnitOfWork'
            );
        }
    }

    public class UnitOfWorkException extends Exception {
    }
}
