global class PostInstallScript implements InstallHandler {

    global void onInstall(InstallContext ctx) {
        try {
            activateSite(ctx.installerId());
        } catch (Exception e) {
            // Do not fail the installation. Admins can manually activate via Setup > Sites.
        }
    }

    private static void activateSite(Id installerId) {
        List<Site> sites = [SELECT Id, Status, AdminId FROM Site WHERE UrlPathPrefix = 'objproof' LIMIT 1];
        if (sites.isEmpty()) return;

        Site s = sites[0];
        s.AdminId = installerId;
        s.Status = 'Active';
        update s;

        assignGuestUserPermissionSet();
    }

    private static void assignGuestUserPermissionSet() {
        // The guest user profile is auto-created by Salesforce with the site label + " Profile"
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

        // Only insert if not already assigned (handles upgrades)
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
