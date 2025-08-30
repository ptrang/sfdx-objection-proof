public with sharing class TaskCalloutService {

    @future(callout=true)
    public static void sendRecordingUrls(Set<Id> taskIds) {
        String context = 'TaskCalloutService.sendRecordingUrls';

        // Query for the tasks to get the token we just generated.
        LoggerService.log('INFO', 'Starting callout process for ' + taskIds.size() + ' tasks [' + String.valueOf(new List<Id>(taskIds)) + '].', context); 
        List<Task> tasksToSend = [
            SELECT Id, Subject, op_recording_url__c, op_callback_token__c,
            op_call_to__c, op_call_from__c,
            WhoId, Who.Name, OwnerId, Owner.Name
            FROM Task WHERE Id IN :taskIds
        ];
        LoggerService.log('INFO', 'Retrieved tasksToSend: ' + String.valueOf(tasksToSend), context);

        // Get the base URL of our public site.
        // NOTE: The Site Name 'Task_Update_Service' must match the name you created.
        // had to remove below due to not testable
        // String callbackBaseUrl;
        // Site sites = [SELECT Id, GuestUserId, UrlPathPrefix FROM Site WHERE Name = 'Task_Update_Service' LIMIT 1];
        // if (sites != null) {
        //     SiteDetail siteDetails = [SELECT Id, DurableId, IsRegistrationEnabled, SecureUrl FROM SiteDetail WHERE DurableId = :sites.Id LIMIT 1];
        //     callbackBaseUrl = siteDetails.SecureUrl + '/services/apexrest/v1/task-callback/';
        // } else {
        //     callbackBaseUrl = '/services/apexrest/v1/task-callback/';
        // } 
        // had to remove above since not testable
        // Dynamically construct the site URL without a query to make it testable.
        String siteUrl = URL.getOrgDomainUrl().toExternalForm();
        String sitePath = Site.getPathPrefix(); // Gets '/task-callback'
        String callbackBaseUrl = siteUrl + sitePath + '/services/apexrest/objectionproof/v1/task-callback/';

        for (Task task : tasksToSend) {
            if (String.isBlank(task.op_callback_token__c)) {
                LoggerService.log('WARN', 'Skipping Task due to blank token. Task Id: ' + task.Id, context);
                continue; // Skip if token generation failed for some reason.
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:objectionproof__objproof_namedcred');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json;charset=UTF-8');

            // Construct the full callback URL with the unique token.
            String fullCallbackUrl = callbackBaseUrl + task.op_callback_token__c;

            Map<String, String> bodyMap = new Map<String, String>{
                'taskId' => task.Id,
                'title' => task.Subject,
                'recordingUrl' => task.op_recording_url__c,
                'callbackUrl' => fullCallbackUrl, // Provide the callback URL to the external service
                'callFrom' => task.op_call_from__c,
                'whoId' => task.WhoId,
                'whoName' => task.Who.Name,
                'callTo' => task.op_call_to__c,
                'ownerId' => task.OwnerId,
                'ownerName' => task.Owner.Name,
                'source' => 'sf-bolder360'
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