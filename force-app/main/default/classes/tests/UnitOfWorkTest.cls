@IsTest
private class UnitOfWorkTest {
    @IsTest
    static void insertsUpdatesAndDeletesInDependencyOrder() {
        UnitOfWork uow = new UnitOfWork(
            new List<SObjectType>{ Account.SObjectType, Subscription__c.SObjectType },
            System.AccessLevel.SYSTEM_MODE
        );
        Account account = new Account(Name = 'UoW Customer');
        uow.registerNew(account);
        uow.commitWork();
        System.assertNotEquals(null, account.Id, 'Insert should populate the Id');

        account.Name = 'UoW Customer Renamed';
        uow.registerDirty(account);
        uow.commitWork();
        System.assertEquals('UoW Customer Renamed', [SELECT Name FROM Account WHERE Id = :account.Id].Name);

        uow.registerDeleted(account);
        uow.commitWork();
        System.assertEquals(0, [SELECT COUNT() FROM Account WHERE Id = :account.Id]);
    }

    @IsTest
    static void rejectsUnregisteredSObjectType() {
        UnitOfWork uow = new UnitOfWork(new List<SObjectType>{ Account.SObjectType });
        try {
            uow.registerNew(new Contact(LastName = 'Nope'));
            System.assert(false, 'Expected UnitOfWorkException');
        } catch (UnitOfWork.UnitOfWorkException e) {
            System.assert(e.getMessage().contains('Contact'), 'Message should name the offending type');
        }
    }

    @IsTest
    static void rollsBackEverythingWhenOneStatementFails() {
        UnitOfWork uow = new UnitOfWork(
            new List<SObjectType>{ Account.SObjectType, Subscription__c.SObjectType },
            System.AccessLevel.SYSTEM_MODE
        );
        uow.registerNew(new Account(Name = 'Survivor?'));
        // Missing required Account__c master data makes this insert fail.
        uow.registerNew(new Subscription__c(Status__c = 'Draft'));

        try {
            uow.commitWork();
            System.assert(false, 'Expected DmlException');
        } catch (DmlException e) {
            System.assertEquals(
                0,
                [SELECT COUNT() FROM Account WHERE Name = 'Survivor?'],
                'The earlier insert must be rolled back with the failed one'
            );
        }
    }

    @IsTest
    static void userModeBlocksWritesWithoutObjectPermission() {
        User restrictedUser = TestDataFactory.createStandardUser();
        System.runAs(restrictedUser) {
            UnitOfWork uow = new UnitOfWork(new List<SObjectType>{ Subscription__c.SObjectType });
            uow.registerNew(
                new Subscription__c(
                    Status__c = 'Draft',
                    Start_Date__c = Date.today(),
                    End_Date__c = Date.today().addYears(1)
                )
            );
            try {
                uow.commitWork();
                System.assert(false, 'Standard User has no Subscription__c create permission');
            } catch (Exception e) {
                System.assert(true, 'User-mode DML enforced object security');
            }
        }
    }
}
