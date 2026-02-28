public with sharing class TaskTriggerHandler {

    public static void onBeforeUpdate(List<Task> newTasks, Map<Id, Task> oldTaskMap) {
        for (Task newTask : newTasks) {
            Task oldTask = oldTaskMap.get(newTask.Id);

            if (newTask.op_recording_url__c != null && oldTask.op_recording_url__c == null) {
                LoggerService.log('INFO', 'Token generation condition MET for Task Id: ' + newTask.Id, 'TaskTriggerHandler.onBeforeUpdate');
                String token = EncodingUtil.base64Encode(Crypto.generateAesKey(128));
                newTask.op_callback_token__c = token.replace('+', '-').replace('/', '_').replace('=', '');
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
            LoggerService.log('INFO', 'Preparing to publish callout event for Task Ids: ' + String.valueOf(new List<Id>(taskIdsForCallout)), 'TaskTriggerHandler.onAfterUpdate');
            publishEvent(taskIdsForCallout);
        }
    }

    private static String getCallbackBaseUrl() {
        List<Site> sites = [SELECT Id FROM Site WHERE UrlPathPrefix = 'objproof' AND Status = 'Active' LIMIT 1];
        if (!sites.isEmpty()) {
            // SiteDetail.SecureURL is the authoritative public HTTPS URL for the site,
            // works across Enhanced Domain orgs (.my.site.com) and classic orgs (.salesforce-sites.com).
            List<SiteDetail> details = [SELECT SecureURL FROM SiteDetail WHERE DurableId = :sites[0].Id LIMIT 1];
            if (!details.isEmpty() && String.isNotBlank(details[0].SecureURL)) {
                return details[0].SecureURL;
            }
        }
        return URL.getOrgDomainUrl().toExternalForm();
    }

    private static void publishEvent(Set<Id> taskIdsForCallout) {
        String context = 'TaskTriggerHandler.publishEvent';

        try {
            String orgUrl = getCallbackBaseUrl();

            List<TaskCalloutEvent__e> events = new List<TaskCalloutEvent__e>();
            for (Id taskId : taskIdsForCallout) {
                events.add(new TaskCalloutEvent__e(
                    TaskId__c = taskId,
                    OrgUrl__c = orgUrl
                ));
            }

            List<Database.SaveResult> results = EventBus.publish(events);

            Integer successCount = 0;
            for (Database.SaveResult result : results) {
                if (!result.isSuccess()) {
                    String errorMsg = 'Failed to publish TaskCalloutEvent: ';
                    for (Database.Error err : result.getErrors()) {
                        errorMsg += err.getMessage() + ' ';
                    }
                    LoggerService.log('ERROR', errorMsg, context);
                } else {
                    successCount++;
                }
            }

            if (successCount > 0) {
                LoggerService.log('INFO', 'Successfully published ' + successCount + ' TaskCalloutEvent(s).', context);
            }

        } catch (Exception e) {
            String errorMessage = 'Error publishing TaskCalloutEvent: ' + e.getMessage() + '\n' + e.getStackTraceString();
            LoggerService.log('ERROR', errorMessage, context);
        }
    }
}