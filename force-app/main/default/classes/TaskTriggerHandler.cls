public with sharing class TaskTriggerHandler {

    public static void onBeforeUpdate(List<Task> newTasks, Map<Id, Task> oldTaskMap) {
        for (Task newTask : newTasks) {
            Task oldTask = oldTaskMap.get(newTask.Id);

            if (newTask.op_recording_url__c != null && oldTask.op_recording_url__c == null) {
                LoggerService.log('INFO', 'Token generation condition MET for Task Id: ' + newTask.Id, 'TaskTriggerHandler.onBeforeUpdate');
                String token = EncodingUtil.base64Encode(Crypto.generateAesKey(128));
                newTask.op_callback_token__c = token.replace('+', '-').replace('/', '_');
            }
        }
    }

    public static void onAfterUpdate(List<Task> newTasks, Map<Id, Task> oldTaskMap) {
        Set<Id> taskIdsForCallout = new Set<Id>();
        for (Task newTask : newTasks) {
            Task oldTask = oldTaskMap.get(newTask.Id);
            
            if (newTask.op_callback_token__c != null && oldTask.op_callback_token__c == null) {
                taskIdsForCallout.add(newTask.Id);
            }
        }

        if (!taskIdsForCallout.isEmpty()) {
            LoggerService.log('INFO', 'Preparing to make callout for Task Ids: ' + String.valueOf(new List<Id>(taskIdsForCallout)), 'TaskTriggerHandler.onAfterUpdate');
            makeCallout(taskIdsForCallout);
        }
    }

    
    private static void makeCallout(Set<Id> taskIdsForCallout) {
        List<Log__c> logsToCreate = new List<Log__c>();
        String context = 'TaskTriggerHandler.makeCallout';
        
        try {
            // Get the base URL of our public site.
            // NOTE: The Site Name 'Task_Update_Service' must match the name you created.
            // Site site = [SELECT Id FROM Site WHERE Name = 'Task_Update_Service' AND Status = 'Active' LIMIT 1];
            // SiteDetail siteDetail = [SELECT SecureUrl FROM SiteDetail WHERE DurableId = :site.Id LIMIT 1];
            // String secureSiteUrl = siteDetail.SecureUrl;
            // Dynamically construct the site URL without a query to make it testable.
            String siteUrl = URL.getOrgDomainUrl().toExternalForm();
            // String sitePath = Site.getPathPrefix(); // Gets '/task-callback'
            // String secureSiteUrl = siteUrl + sitePath;

            // Create an instance of the Queueable class and enqueue it.
            System.enqueueJob(new TaskCalloutService(taskIdsForCallout, siteUrl));
            LoggerService.log('INFO', 'Successfully enqueued TaskCalloutService job for ' + taskIdsForCallout.size() + ' tasks.', context);

        } catch (Exception e) {
            // Log the error to the custom object so it's visible in the subscriber org.
            String errorMessage = 'Error finding Site or queuing callout: ' + e.getMessage() + '\n' + e.getStackTraceString();
            LoggerService.log('ERROR', errorMessage, context);
        }
    }
}