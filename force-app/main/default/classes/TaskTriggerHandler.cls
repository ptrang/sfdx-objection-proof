public with sharing class TaskTriggerHandler {

    // No changes to method signatures needed. The sObject types are namespace-aware.
    public static void onBeforeUpdate(List<Task> newTasks, Map<Id, Task> oldTaskMap) {
        for (Task newTask : newTasks) {
            Task oldTask = oldTaskMap.get(newTask.Id);
            // Reference fields using the __c suffix. The compiler resolves the namespace.
            if (newTask.objectionproof__recording_url__c != null && oldTask.objectionproof__recording_url__c == null) {
                Blob cryptoKey = Crypto.generateAesKey(128);
                newTask.objectionproof__callback_token__c = EncodingUtil.base64Encode(cryptoKey);
            }
        }
    }

    public static void onAfterUpdate(List<Task> newTasks, Map<Id, Task> oldTaskMap) {
        // ... Logic is the same, just with namespaced fields ...
        Set<Id> taskIdsForCallout = new Set<Id>();
        for (Task newTask : newTasks) {
            Task oldTask = oldTaskMap.get(newTask.Id);
            if (newTask.objectionproof__recording_url__c != null && oldTask.objectionproof__recording_url__c == null) {
                taskIdsForCallout.add(newTask.Id);
            }
        }

        if (!taskIdsForCallout.isEmpty()) {
            TaskCalloutService.sendRecordingUrls(taskIdsForCallout);
        }
    }
}