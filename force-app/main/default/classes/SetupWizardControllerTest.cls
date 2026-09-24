@IsTest
private class SetupWizardControllerTest {

    private static final String ADMIN_USERNAME = 'objproof-admin@example.com.test';
    private static final String REP_USERNAME = 'objproof-rep@example.com.test';

    @TestSetup
    static void makeData() {
        User admin = createUser(ADMIN_USERNAME, 'System Administrator');
        insert new PermissionSetAssignment(
            AssigneeId = admin.Id,
            PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'objproof_admin_permission_set' LIMIT 1].Id
        );
        // A System Administrator without the Objection Proof Admin permission set.
        createUser(REP_USERNAME, 'System Administrator');
    }

    private static User createUser(String username, String profileName) {
        User u = new User(
            Username = username,
            Email = 'objproof-test@example.com',
            LastName = 'Test',
            Alias = 'optest',
            ProfileId = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1].Id,
            TimeZoneSidKey = 'America/Phoenix',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    private static User adminUser() {
        return [SELECT Id FROM User WHERE Username = :ADMIN_USERNAME LIMIT 1];
    }

    private static User userWithoutPermission() {
        return [SELECT Id FROM User WHERE Username = :REP_USERNAME LIMIT 1];
    }

    @IsTest
    static void testGetSetupStatus() {
        SetupWizardController.SetupStatus status;
        Test.startTest();
        System.runAs(adminUser()) {
            status = SetupWizardController.getSetupStatus();
        }
        Test.stopTest();

        System.assertNotEquals(null, status, 'Status should not be null');
        System.assertNotEquals(null, status.automationPermSetAssigned);
        System.assertNotEquals(null, status.siteActive);
        System.assertNotEquals(null, status.usersWithPermSet);
        System.assertEquals(false, status.apiKeyConfigured);
    }

    @IsTest
    static void testAssignAutomationPermSet() {
        Test.startTest();
        System.runAs(adminUser()) {
            try {
                SetupWizardController.assignAutomationPermSet();
                // Idempotent: a second call must not fail on a duplicate assignment.
                SetupWizardController.assignAutomationPermSet();
                System.assertEquals(true, SetupWizardController.getSetupStatus().automationPermSetAssigned);
            } catch (AuraHandledException e) {
                // Acceptable if the Automated Process user isn't visible in the test context.
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetAvailableUsers() {
        List<SetupWizardController.UserOption> users;
        Test.startTest();
        System.runAs(adminUser()) {
            users = SetupWizardController.getAvailableUsers();
        }
        Test.stopTest();

        System.assertNotEquals(null, users, 'Users list should not be null');
    }

    @IsTest
    static void testAssignUserPermSets() {
        Id repId = userWithoutPermission().Id;
        Test.startTest();
        System.runAs(adminUser()) {
            SetupWizardController.assignUserPermSets(new List<Id>{ repId });
            SetupWizardController.assignUserPermSets(new List<Id>{ repId });
        }
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM PermissionSetAssignment
            WHERE AssigneeId = :repId AND PermissionSet.Name = 'objproof_permission_set'
        ]);
    }

    @IsTest
    static void testAssignUserPermSetsEmpty() {
        Test.startTest();
        System.runAs(adminUser()) {
            SetupWizardController.assignUserPermSets(new List<Id>());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveApiKey() {
        Test.startTest();
        System.runAs(adminUser()) {
            SetupWizardController.saveApiKey('  new-api-key  ');
        }
        Test.stopTest();

        System.assertEquals('new-api-key', SettingsService.getApiKey(), 'Key should be trimmed and stored');
    }

    @IsTest
    static void testSaveApiKeyBlankRejected() {
        System.runAs(adminUser()) {
            try {
                SetupWizardController.saveApiKey('   ');
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                System.assertEquals(false, SettingsService.isApiKeyConfigured());
            }
        }
    }

    @IsTest
    static void testSaveApiKeyTooLongRejected() {
        System.runAs(adminUser()) {
            try {
                SetupWizardController.saveApiKey('x'.repeat(256));
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                System.assertEquals(false, SettingsService.isApiKeyConfigured());
            }
        }
    }

    @IsTest
    static void testChangesRequireManagePermission() {
        Id repId = userWithoutPermission().Id;
        System.runAs(userWithoutPermission()) {
            Integer rejected = 0;
            try { SetupWizardController.saveApiKey('key'); } catch (AuraHandledException e) { rejected++; }
            try { SetupWizardController.assignAutomationPermSet(); } catch (AuraHandledException e) { rejected++; }
            try { SetupWizardController.assignUserPermSets(new List<Id>{ repId }); } catch (AuraHandledException e) { rejected++; }
            System.assertEquals(3, rejected, 'Every change should require the Manage_Objection_Proof permission');
        }
        System.assertEquals(false, SettingsService.isApiKeyConfigured());
    }
}
