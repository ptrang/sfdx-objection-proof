// without sharing: install handlers run in a privileged context and must be able
// to query and assign permission sets regardless of the installer's sharing access.
global without sharing class PostInstallScript implements InstallHandler {

    global void onInstall(InstallContext ctx) {
        try {
            // The Site is deployed inactive — admin must activate via Setup > Sites.
            // The guest user (ObjProof Profile) is created by Salesforce on site deploy,
            // so we can assign its permission set now even before activation.
            assignGuestUserPermissionSet();
        } catch (Exception e) {
            // Do not fail the installation. Admin can assign the permission set manually
            // via Setup > Sites > ObjProof > Public Access Settings if needed.
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
}
