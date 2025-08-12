public with sharing class TaskCalloutService {

    @future(callout=true)
    public static void sendRecordingUrls(Set<Id> taskIds) {
        // Get the site name from our new custom setting.
        objectionproof__ObjectionProof_Settings__c settings = objectionproof__ObjectionProof_Settings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.objectionproof__Site_Name__c)) {
            System.debug(LoggingLevel.ERROR, 'ObjectionProof Setup Error: The Site Name is not configured in ObjectionProof Settings custom settings.');
            return;
        }

        List<Task> tasksToSend = [
            SELECT Id, objectionproof__recording_url__c, objectionproof__callback_token__c
            FROM Task WHERE Id IN :taskIds
        ];

        // Look up the Site using the name from custom settings.
        List<Site> siteDetailsList = [SELECT GuestUserId FROM Site WHERE Name = :settings.objectionproof__Site_Name__c LIMIT 1];
        if (siteDetailsList.isEmpty()){
            System.debug(LoggingLevel.ERROR, 'ObjectionProof Site Error: Could not find a Site with the name specified in custom settings: ' + settings.objectionproof__Site_Name__c);
            return;
        }

        String siteUrl = Site.getSecureUrl(siteDetailsList[0].getGuestUserId()).removeEnd('/s');
        String callbackBaseUrl = siteUrl + '/services/apexrest/v1/task-callback/';

        // ... (rest of the logic is the same)
        for (Task task : tasksToSend) {
            // ...
        }
    }
}