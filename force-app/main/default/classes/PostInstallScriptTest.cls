@IsTest
private class PostInstallScriptTest {

    @IsTest
    static void testInstallAssignsInstallerPermissionSets() {
        Test.startTest();
        Test.testInstall(new PostInstallScript(), null);
        Test.stopTest();

        Set<String> assigned = new Set<String>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSet.Name FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
        ]) {
            assigned.add(psa.PermissionSet.Name);
        }
        System.assert(assigned.contains('objproof_permission_set'), 'Installer should get the user permission set');
        System.assert(assigned.contains('objproof_admin_permission_set'), 'Installer should get the admin permission set');

        List<Log__c> logs = [SELECT Level__c, Message__c FROM Log__c WHERE Context__c = 'PostInstallScript'];
        System.assertEquals(1, logs.size(), 'Each install should write one summary row');
        System.assert(logs[0].Message__c.contains('installer=' + UserInfo.getUserId()), logs[0].Message__c);
        System.assert(!logs[0].Message__c.contains('FAILED'), logs[0].Message__c);
    }

    @IsTest
    static void testUpgradeIsIdempotent() {
        Test.startTest();
        Test.testInstall(new PostInstallScript(), null);
        Test.testInstall(new PostInstallScript(), new Version(1, 11), false);
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSet.Name = 'objproof_admin_permission_set'
        ]);
    }
}
