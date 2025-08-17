public with sharing class TaskCalloutService {

    @future(callout=true)
    public static void sendRecordingUrls(Set<Id> taskIds) {
        // Query for the tasks to get the token we just generated.
        List<Task> tasksToSend = [
            SELECT Id, op_recording_url__c, op_callback_token__c
            FROM Task WHERE Id IN :taskIds
        ];

        // Get the base URL of our public site.
        // NOTE: The Site Name 'Task_Update_Service' must match the name you created.
        Site siteDetails = [SELECT GuestUserId FROM Site WHERE Name = 'Task_Update_Service' LIMIT 1];
        // String siteUrl = Site.getSecureUrl(siteDetails.getGuestUserId()).removeEnd('/s');
        String siteUrl = Url.getOrgDomainUrl().toExternalForm();
        String callbackBaseUrl = siteUrl + '/services/apexrest/v1/task-callback/';

        for (Task task : tasksToSend) {
            if (String.isBlank(task.op_callback_token__c)) {
                continue; // Skip if token generation failed for some reason.
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Recording_Service');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json;charset=UTF-8');

            // Construct the full callback URL with the unique token.
            String fullCallbackUrl = callbackBaseUrl + task.op_callback_token__c;

            Map<String, String> bodyMap = new Map<String, String>{
                'taskId' => task.Id,
                'recordingUrl' => task.op_recording_url__c,
                'callbackUrl' => fullCallbackUrl // Provide the callback URL to the external service
            };
            req.setBody(JSON.serialize(bodyMap));

            // ... (The rest of the Http().send(req) logic remains the same as previous version)
            // ... (No need to process response here anymore)
            Http http = new Http();
            try {
                 http.send(req);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Outbound callout failed for Task Id: ' + task.Id + '. Error: ' + e.getMessage());
            }
        }
    }
}