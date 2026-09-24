// without sharing + SYSTEM_MODE: install handlers run as a special package
// installation user, not the installer, so user-mode access checks don't apply.
// The script only assigns this package's own permission sets to the installer and
// to the ObjProof Site guest user.
public without sharing class PostInstallScript implements InstallHandler {

    public void onInstall(InstallContext ctx) {
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
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (guestUsers.isEmpty()) return;

        List<PermissionSet> permSets = [
            SELECT Id FROM PermissionSet
            WHERE Name = 'objproof_site_permission_set'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (permSets.isEmpty()) return;

        List<PermissionSetAssignment> existing = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :guestUsers[0].Id
            AND PermissionSetId = :permSets[0].Id
            WITH SYSTEM_MODE
        ];
        if (existing.isEmpty()) {
            Database.insert(new PermissionSetAssignment(
                AssigneeId = guestUsers[0].Id,
                PermissionSetId = permSets[0].Id
            ), AccessLevel.SYSTEM_MODE);
        }
    }

    private static void assignInstallerPermissionSet(Id installerId, String permSetName) {
        if (installerId == null) return;

        List<PermissionSet> permSets = [
            SELECT Id FROM PermissionSet
            WHERE Name = :permSetName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (permSets.isEmpty()) return;

        List<PermissionSetAssignment> existing = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :installerId
            AND PermissionSetId = :permSets[0].Id
            WITH SYSTEM_MODE
        ];
        if (existing.isEmpty()) {
            Database.insert(new PermissionSetAssignment(
                AssigneeId = installerId,
                PermissionSetId = permSets[0].Id
            ), AccessLevel.SYSTEM_MODE);
        }
    }
}
