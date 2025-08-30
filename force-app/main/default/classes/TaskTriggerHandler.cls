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
        try {
            TaskCalloutService.sendRecordingUrls(taskIdsForCallout);
            LoggerService.log('INFO', 'Successfully queued callout for ' + taskIdsForCallout.size() + ' tasks.', 'TaskTriggerHandler.makeCallout');

        } catch (Exception e) {
            // Log the error to the custom object so it's visible in the subscriber org.
            String errorMessage = 'Error finding Site or queuing callout: ' + e.getMessage() + '\n' + e.getStackTraceString();
            LoggerService.log('ERROR', errorMessage, 'TaskTriggerHandler.makeCallout');
        }
    }
}