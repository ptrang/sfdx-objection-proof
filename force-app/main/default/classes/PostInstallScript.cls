// without sharing + SYSTEM_MODE: install handlers run as a special package
// installation user, not the installer, so user-mode access checks don't apply.
// The script only assigns this package's own permission sets to the installer and
// to the ObjProof Site guest user.
global without sharing class PostInstallScript implements InstallHandler {

    global void onInstall(InstallContext ctx) {
        // One summary row per install, so an admin (or we) can see what happened.
        List<String> notes = new List<String>{
            'installer=' + ctx.installerID(),
            'upgrade=' + ctx.isUpgrade(),
            'previousVersion=' + ctx.previousVersion()
        };
        try {
            notes.add('guest: ' + assignGuestUserPermissionSet());
        } catch (Exception e) {
            // Do not fail the installation. Admin can assign the permission set manually
            // via Setup > Sites > ObjProof > Public Access Settings if needed.
            notes.add('guest FAILED: ' + e.getMessage());
        }
        for (String name : new List<String>{ 'objproof_permission_set', 'objproof_admin_permission_set' }) {
            try {
                notes.add(name + ': ' + assignInstallerPermissionSet(ctx.installerID(), name));
            } catch (Exception e) {
                // Do not fail the installation. Admin can assign the permission set manually.
                notes.add(name + ' FAILED: ' + e.getMessage());
            }
        }
        recordSummary(String.join(notes, '; '));
    }

    // Install errors can't fail the install and are otherwise invisible, so write
    // the summary to Log__c regardless of the Logging_Enabled setting.
    private static void recordSummary(String message) {
        try {
            Database.insert(new Log__c(
                Level__c = message.contains('FAILED') ? 'ERROR' : 'INFO',
                Context__c = 'PostInstallScript',
                Message__c = message
            ), AccessLevel.SYSTEM_MODE);
        } catch (Exception ignored) {
            // Nothing else can be done during install.
        }
    }

    private static String assignGuestUserPermissionSet() {
        List<User> guestUsers = [
            SELECT Id FROM User
            WHERE Profile.Name = 'ObjProof Profile'
            AND IsActive = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (guestUsers.isEmpty()) return 'no ObjProof site guest user yet';
        return assign(guestUsers[0].Id, 'objproof_site_permission_set');
    }

    private static String assignInstallerPermissionSet(Id installerId, String permSetName) {
        if (installerId == null) return 'skipped, no installer id';
        return assign(installerId, permSetName);
    }

    private static String assign(Id userId, String permSetName) {
        List<PermissionSet> permSets = [
            SELECT Id FROM PermissionSet
            WHERE Name = :permSetName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (permSets.isEmpty()) return 'permission set not found';

        List<PermissionSetAssignment> existing = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
            AND PermissionSetId = :permSets[0].Id
            WITH SYSTEM_MODE
        ];
        if (!existing.isEmpty()) return 'already assigned';

        Database.insert(new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = permSets[0].Id
        ), AccessLevel.SYSTEM_MODE);
        return 'assigned';
    }
}
