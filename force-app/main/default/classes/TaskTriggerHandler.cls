public with sharing class TaskTriggerHandler {

    // Runs before the record is saved to generate the callback token.
    public static void onBeforeUpdate(List<Task> newTasks, Map<Id, Task> oldTaskMap) {
        for (Task newTask : newTasks) {
            Task oldTask = oldTaskMap.get(newTask.Id);

            // Generate a token ONLY when the recording URL is first populated.
            if (newTask.op_recording_url__c != null && oldTask.op_recording_url__c == null) {
                // Generate 128 bits of randomness and Base64 encode it for a URL-safe, highly unique token.
                Blob cryptoKey = Crypto.generateAesKey(128);
                newTask.op_callback_token__c = EncodingUtil.base64Encode(cryptoKey);
            }
        }
    }

    // Runs after the record is saved to make the outbound callout.
    public static void onAfterUpdate(List<Task> newTasks, Map<Id, Task> oldTaskMap) {
        Set<Id> taskIdsForCallout = new Set<Id>();
        for (Task newTask : newTasks) {
            Task oldTask = oldTaskMap.get(newTask.Id);
            // Initiate the callout ONLY when the recording URL has been newly added.
            if (newTask.op_recording_url__c != null && oldTask.op_recording_url__c == null) {
                taskIdsForCallout.add(newTask.Id);
            }
        }

        if (!taskIdsForCallout.isEmpty()) {
            TaskCalloutService.sendRecordingUrls(taskIdsForCallout);
        }
    }
}