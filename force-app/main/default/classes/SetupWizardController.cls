// Queries and DML run in USER_MODE: the admin's own object, field and sharing
// access applies, and assigning permission sets requires their "Assign Permission
// Sets" permission. Changes also require the Manage_Objection_Proof custom
// permission (objproof_admin_permission_set).
public with sharing class SetupWizardController {

    @TestVisible
    private static final String MANAGE_PERMISSION = 'Manage_Objection_Proof';

    public class SetupStatus {
        @AuraEnabled public Boolean automationPermSetAssigned;
        @AuraEnabled public Boolean siteActive;
        @AuraEnabled public String siteUrl;
        @AuraEnabled public Integer usersWithPermSet;
        @AuraEnabled public Boolean apiKeyConfigured;
    }

    public class UserOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    @AuraEnabled(cacheable=true)
    public static SetupStatus getSetupStatus() {
        SetupStatus status = new SetupStatus();

        Id autoUserId = getAutomatedProcessUserId();
        if (autoUserId != null) {
            Integer count = [
                SELECT COUNT() FROM PermissionSetAssignment
                WHERE AssigneeId = :autoUserId
                AND PermissionSet.Name = 'objproof_automation_permission_set'
                WITH USER_MODE
            ];
            status.automationPermSetAssigned = count > 0;
        } else {
            status.automationPermSetAssigned = false;
        }

        List<Site> sites = [
            SELECT Id, Status FROM Site
            WHERE UrlPathPrefix = 'objproof'
            WITH USER_MODE
            LIMIT 1
        ];
        status.siteActive = !sites.isEmpty() && sites[0].Status == 'Active';

        if (status.siteActive) {
            List<SiteDetail> details = [
                SELECT SecureURL FROM SiteDetail
                WHERE DurableId = :sites[0].Id
                WITH USER_MODE
            ];
            if (!details.isEmpty()) {
                status.siteUrl = details[0].SecureURL;
            }
        }

        status.usersWithPermSet = [
            SELECT COUNT() FROM PermissionSetAssignment
            WHERE PermissionSet.Name = 'objproof_permission_set'
            AND Assignee.IsActive = true
            WITH USER_MODE
        ];

        status.apiKeyConfigured = SettingsService.isApiKeyConfigured();

        return status;
    }

    @AuraEnabled
    public static void assignAutomationPermSet() {
        requireManagePermission();
        Id autoUserId = getAutomatedProcessUserId();
        if (autoUserId == null) {
            throw new AuraHandledException('Automated Process user not found.');
        }

        Id permSetId = getPermissionSetId('objproof_automation_permission_set');
        if (permSetId == null) {
            throw new AuraHandledException('Automation permission set not found.');
        }

        Integer existing = [
            SELECT COUNT() FROM PermissionSetAssignment
            WHERE AssigneeId = :autoUserId
            AND PermissionSetId = :permSetId
            WITH USER_MODE
        ];

        if (existing == 0) {
            Database.insert(new PermissionSetAssignment(
                AssigneeId = autoUserId,
                PermissionSetId = permSetId
            ), AccessLevel.USER_MODE);
        }
    }

    // Write-only: the key is never returned to the client.
    @AuraEnabled
    public static void saveApiKey(String apiKey) {
        requireManagePermission();
        if (String.isBlank(apiKey)) {
            throw new AuraHandledException('API key is required.');
        }
        if (apiKey.trim().length() > 255) {
            throw new AuraHandledException('API key must be 255 characters or fewer.');
        }
        SettingsService.setApiKey(apiKey.trim());
        // Register the org with Objection Proof. The callout runs as the Automated
        // Process user, which holds the named credential access; published after
        // commit so it only fires if the key was saved.
        EventBus.publish(new OrgRegistrationEvent__e(RequestedBy__c = UserInfo.getUserId()));
    }

    @AuraEnabled(cacheable=true)
    public static List<UserOption> getAvailableUsers() {
        Set<Id> assignedUserIds = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId FROM PermissionSetAssignment
            WHERE PermissionSet.Name = 'objproof_permission_set'
            WITH USER_MODE
        ]) {
            assignedUserIds.add(psa.AssigneeId);
        }

        List<UserOption> options = new List<UserOption>();
        for (User u : [
            SELECT Id, Name, Profile.Name
            FROM User
            WHERE IsActive = true
            AND UserType = 'Standard'
            AND Id NOT IN :assignedUserIds
            WITH USER_MODE
            ORDER BY Name
            LIMIT 200
        ]) {
            UserOption opt = new UserOption();
            opt.value = u.Id;
            opt.label = u.Name + ' (' + u.Profile.Name + ')';
            options.add(opt);
        }
        return options;
    }

    @AuraEnabled
    public static void assignUserPermSets(List<Id> userIds) {
        requireManagePermission();
        Id permSetId = getPermissionSetId('objproof_permission_set');
        if (permSetId == null) {
            throw new AuraHandledException('Permission set not found.');
        }

        Set<Id> alreadyAssigned = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId FROM PermissionSetAssignment
            WHERE PermissionSetId = :permSetId
            AND AssigneeId IN :userIds
            WITH USER_MODE
        ]) {
            alreadyAssigned.add(psa.AssigneeId);
        }

        List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
        for (Id userId : userIds) {
            if (!alreadyAssigned.contains(userId)) {
                toInsert.add(new PermissionSetAssignment(
                    AssigneeId = userId,
                    PermissionSetId = permSetId
                ));
            }
        }

        if (!toInsert.isEmpty()) {
            Database.insert(toInsert, AccessLevel.USER_MODE);
        }
    }

    private static void requireManagePermission() {
        if (!FeatureManagement.checkPermission(MANAGE_PERMISSION)) {
            throw new AuraHandledException('You need the Objection Proof Admin permission set to change these settings.');
        }
    }

    private static Id getAutomatedProcessUserId() {
        List<User> users = [
            SELECT Id FROM User
            WHERE Name = 'Automated Process'
            AND IsActive = true
            WITH USER_MODE
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0].Id;
    }

    private static Id getPermissionSetId(String name) {
        List<PermissionSet> ps = [
            SELECT Id FROM PermissionSet
            WHERE Name = :name
            WITH USER_MODE
            LIMIT 1
        ];
        return ps.isEmpty() ? null : ps[0].Id;
    }
}
