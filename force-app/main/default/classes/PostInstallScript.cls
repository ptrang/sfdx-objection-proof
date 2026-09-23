// without sharing: install handlers run in a privileged context and must be able
// to query and assign permission sets regardless of the installer's sharing access.
global without sharing class PostInstallScript implements InstallHandler {

    global void onInstall(InstallContext ctx) {
        try {
            assignGuestUserPermissionSet();
        } catch (Exception e) {
            // Do not fail the installation. Admin can assign the permission set manually
            // via Setup > Sites > ObjProof > Public Access Settings if needed.
        }
        try {
            assignInstallerPermissionSet(ctx.installerID(), 'objproof_permission_set');
            assignInstallerPermissionSet(ctx.installerID(), 'objproof_admin_permission_set');
        } catch (Exception e) {
            // Do not fail the installation. Admin can assign the permission set manually.
        }
    }

    private static void assignGuestUserPermissionSet() {
        List<User> guestUsers = [
            SELECT Id FROM User
            WHERE Profile.Name = 'ObjProof Profile'
            AND IsActive = true
            LIMIT 1
        ];
        if (guestUsers.isEmpty()) return;

        List<PermissionSet> permSets = [
            SELECT Id FROM PermissionSet
            WHERE Name = 'objproof_site_permission_set'
            LIMIT 1
        ];
        if (permSets.isEmpty()) return;

        List<PermissionSetAssignment> existing = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :guestUsers[0].Id
            AND PermissionSetId = :permSets[0].Id
        ];
        if (existing.isEmpty()) {
            insert new PermissionSetAssignment(
                AssigneeId = guestUsers[0].Id,
                PermissionSetId = permSets[0].Id
            );
        }
    }

    private static void assignInstallerPermissionSet(Id installerId, String permSetName) {
        if (installerId == null) return;

        List<PermissionSet> permSets = [
            SELECT Id FROM PermissionSet
            WHERE Name = :permSetName
            LIMIT 1
        ];
        if (permSets.isEmpty()) return;

        List<PermissionSetAssignment> existing = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :installerId
            AND PermissionSetId = :permSets[0].Id
        ];
        if (existing.isEmpty()) {
            insert new PermissionSetAssignment(
                AssigneeId = installerId,
                PermissionSetId = permSets[0].Id
            );
        }
    }
}
