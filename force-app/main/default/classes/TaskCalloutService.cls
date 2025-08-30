public class TaskCalloutService implements Queueable, Database.AllowsCallouts {

    private final Set<Id> taskIds;
    private final String secureSiteUrl;

    // The constructor now accepts the data from the trigger
    public TaskCalloutService(Set<Id> taskIds, String secureSiteUrl) {
        this.taskIds = taskIds;
        this.secureSiteUrl = secureSiteUrl;
    }

    public void execute(QueueableContext context) {
        // --- The rest of the logic is moved inside the execute method ---
        Id triggeringUserId = UserInfo.getUserId();

        List<Log__c> logsToCreate = new List<Log__c>();
        String logContext = 'TaskCalloutService.execute';
        
        logsToCreate.add(new Log__c(
            objectionproof__Level__c = 'INFO',
            objectionproof__Message__c = 'Starting callout process for ' + taskIds.size() + ' tasks.',
            objectionproof__Context__c = logContext,
            objectionproof__Triggering_User__c = triggeringUserId // Add user to log
        ));

        List<Task> tasksToSend = [
            SELECT Id, Subject, objectionproof__op_recording_url__c, objectionproof__op_callback_token__c,
                   objectionproof__op_call_to__c, objectionproof__op_call_from__c,
                   WhoId, Who.Name, OwnerId, Owner.Name
            FROM Task WHERE Id IN :taskIds
        ];

        // This check is still valuable for detecting tasks deleted by other means
        if (tasksToSend.size() != taskIds.size()) {
            Set<Id> foundTaskIds = (new Map<Id, SObject>(tasksToSend)).keySet();
            Set<Id> missingTaskIds = new Set<Id>(taskIds);
            missingTaskIds.removeAll(foundTaskIds);
            logsToCreate.add(new Log__c(
                objectionproof__Level__c = 'WARN',
                objectionproof__Message__c = 'Missing Tasks (likely deleted after queuing): ' + String.valueOf(new List<Id>(missingTaskIds)),
                objectionproof__Context__c = logContext,
                objectionproof__Triggering_User__c = triggeringUserId // Add user to log
            ));
        }

        String callbackBaseUrl = this.secureSiteUrl + '/services/apexrest/objectionproof/v1/task-callback/';
        try {
            for (Task task : tasksToSend) {
                if (String.isBlank(task.op_callback_token__c)) {
                    logsToCreate.add(new Log__c(
                            objectionproof__Level__c = 'WARN',
                            objectionproof__Message__c = 'Skipping Task due to blank token. Task Id: ' + task.Id,
                            objectionproof__Context__c = logContext,
                            objectionproof__Triggering_User__c = triggeringUserId // Add user to log
                        ));
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
                String requestBody = JSON.serialize(bodyMap);
                req.setBody(requestBody);
    
                logsToCreate.add(new Log__c(
                        objectionproof__Level__c = 'DEBUG',
                        objectionproof__Message__c = 'Sending request for Task Id: ' + task.Id + '. Body: ' + requestBody,
                        objectionproof__Context__c = logContext,
                        objectionproof__Triggering_User__c = triggeringUserId // Add user to log
                    ));
    
                // ... (The rest of the Http().send(req) logic remains the same as previous version)
                // ... (No need to process response here anymore)
                Http http = new Http();
                try {
                     http.send(req);
                } catch (Exception e) {
                    // This is the most critical log entry. It captures the error.
                    String errorMessage = 'Outbound callout failed for Task Id: ' + task.Id + '. Error: ' + e.getMessage() + '\n' + e.getStackTraceString();
                    logsToCreate.add(new Log__c(
                        objectionproof__Level__c = 'ERROR',
                        objectionproof__Message__c = errorMessage,
                        objectionproof__Context__c = logContext,
                        objectionproof__Triggering_User__c = triggeringUserId // Add user to log
                    ));
                }
            }
        } catch (Exception e) {
            // This is the most critical log entry. It captures the error.
            String errorMessage = 'Failed in the task array for loop. Error: ' + e.getMessage() + '\n' + e.getStackTraceString();
            logsToCreate.add(new Log__c(
                    objectionproof__Level__c = 'ERROR',
                    objectionproof__Message__c = errorMessage,
                    objectionproof__Context__c = logContext,
                    objectionproof__Triggering_User__c = triggeringUserId // Add user to log
                ));
        }

        logsToCreate.add(new Log__c(
            objectionproof__Level__c = 'INFO',
            objectionproof__Message__c = 'Callout process finished.',
            objectionproof__Context__c = logContext,
            objectionproof__Triggering_User__c = triggeringUserId // Add user to log
        ));

        // --- NEW: Perform all logging in a single, safe DML operation at the end ---
        LoggerService.log(logsToCreate);
    }
}