public with sharing class TaskTriggerHandler {

    // Runs before an EXISTING record is saved
    public static void onBeforeUpdate(List<Task> newTasks, Map<Id, Task> oldTaskMap) {
        System.debug('--- TaskTriggerHandler: onBeforeUpdate STARTS ---');
        for (Task newTask : newTasks) {
            Task oldTask = oldTaskMap.get(newTask.Id);

            // Generate a token ONLY when the recording URL is first populated.
            if (newTask.op_recording_url__c != null && oldTask.op_recording_url__c == null) {
                System.debug('Token Generation Condition MET for Task Id: ' + newTask.Id);
                String token = EncodingUtil.base64Encode(Crypto.generateAesKey(128));
                newTask.op_callback_token__c = token.replace('+', '-').replace('/', '_');
                System.debug('Generated new token: ' + newTask.op_callback_token__c);
            } else {
                System.debug('Token Generation Condition NOT MET for Task Id: ' + newTask.Id);
            }
        }
        System.debug('--- TaskTriggerHandler: onBeforeUpdate ENDS ---');
    }

    // Runs after an EXISTING record is saved
    public static void onAfterUpdate(List<Task> newTasks, Map<Id, Task> oldTaskMap) {
        System.debug('--- TaskTriggerHandler: onAfterUpdate STARTS ---');
        Set<Id> taskIdsForCallout = new Set<Id>();
        for (Task newTask : newTasks) {
            Task oldTask = oldTaskMap.get(newTask.Id);
            // Initiate the callout ONLY when the recording URL has been newly added.
            if (newTask.op_recording_url__c != null && oldTask.op_recording_url__c == null) {
                System.debug('Callout Condition MET for Task Id: ' + newTask.Id);
                taskIdsForCallout.add(newTask.Id);
            } else {
                System.debug('Callout Condition NOT MET for Task Id: ' + newTask.Id + '. Old URL: ' + oldTask.op_recording_url__c + ', New URL: ' + newTask.op_recording_url__c);
            }
        }

        if (!taskIdsForCallout.isEmpty()) {
            System.debug('Preparing to make callout for Task Ids: ' + taskIdsForCallout);
            makeCallout(taskIdsForCallout);
        }
        System.debug('--- TaskTriggerHandler: onAfterUpdate ENDS ---');
    }

    // Centralized method to handle the callout logic.
    private static void makeCallout(Set<Id> taskIdsForCallout) {
        try {
            TaskCalloutService.sendRecordingUrls(taskIdsForCallout);
            System.debug('TaskTriggerHandler makeCallout:Successfully queued callout.');

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'TaskTriggerHandler makeCallout Error: ' + e.getMessage());
        }
    }
    
    // NOTE: You would also add onBeforeInsert and onAfterInsert methods here for completeness,
    // but they are omitted for clarity as the issue is with the update logic.
}