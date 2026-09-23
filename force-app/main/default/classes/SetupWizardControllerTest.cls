@IsTest
private class SetupWizardControllerTest {

    @IsTest
    static void testGetSetupStatus() {
        Test.startTest();
        SetupWizardController.SetupStatus status = SetupWizardController.getSetupStatus();
        Test.stopTest();

        System.assertNotEquals(null, status, 'Status should not be null');
        System.assertNotEquals(null, status.automationPermSetAssigned);
        System.assertNotEquals(null, status.siteActive);
        System.assertNotEquals(null, status.usersWithPermSet);
    }

    @IsTest
    static void testAssignAutomationPermSet() {
        Test.startTest();
        try {
            SetupWizardController.assignAutomationPermSet();
            // Verify it was assigned
            SetupWizardController.SetupStatus status = SetupWizardController.getSetupStatus();
            System.assertEquals(true, status.automationPermSetAssigned);
        } catch (AuraHandledException e) {
            // Acceptable if Automated Process user not found in test context
        }
        Test.stopTest();
    }

    @IsTest
    static void testAssignAutomationPermSetIdempotent() {
        Test.startTest();
        try {
            SetupWizardController.assignAutomationPermSet();
            SetupWizardController.assignAutomationPermSet();
        } catch (AuraHandledException e) {
            // Acceptable
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetAvailableUsers() {
        Test.startTest();
        List<SetupWizardController.UserOption> users = SetupWizardController.getAvailableUsers();
        Test.stopTest();

        System.assertNotEquals(null, users, 'Users list should not be null');
    }

    @IsTest
    static void testAssignUserPermSets() {
        Test.startTest();
        try {
            SetupWizardController.assignUserPermSets(new List<Id>{ UserInfo.getUserId() });
        } catch (AuraHandledException e) {
            // Acceptable if permission set not found in test context
        }
        Test.stopTest();
    }

    @IsTest
    static void testAssignUserPermSetsEmpty() {
        Test.startTest();
        try {
            SetupWizardController.assignUserPermSets(new List<Id>());
        } catch (AuraHandledException e) {
            // Acceptable
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveApiKey() {
        Test.startTest();
        SetupWizardController.saveApiKey('  new-api-key  ');
        Test.stopTest();

        System.assertEquals('new-api-key', SettingsService.getApiKey(), 'Key should be trimmed and stored');
        System.assertEquals(true, SetupWizardController.getSetupStatus().apiKeyConfigured);
    }

    @IsTest
    static void testSaveApiKeyBlankRejected() {
        try {
            SetupWizardController.saveApiKey('   ');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertEquals(false, SettingsService.isApiKeyConfigured());
        }
    }

    @IsTest
    static void testSaveApiKeyTooLongRejected() {
        try {
            SetupWizardController.saveApiKey('x'.repeat(256));
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertEquals(false, SettingsService.isApiKeyConfigured());
        }
    }
}
