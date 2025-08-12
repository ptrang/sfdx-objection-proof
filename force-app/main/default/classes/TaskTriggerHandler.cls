public with sharing class TaskTriggerHandler {

    public static void onAfterUpdate(List<Task> newTasks, Map<Id, Task> oldTaskMap) {
        Set<Id> taskIdsForCallout = new Set<Id>();

        for (Task newTask : newTasks) {
            Task oldTask = oldTaskMap.get(newTask.Id);

            // Condition: The recording URL has a new value and is not the same as the old value.
            // This captures both setting it for the first time (null -> value)
            // and changing it (value1 -> value2).
            if (newTask.recording_url__c != null && newTask.recording_url__c != oldTask.recording_url__c) {
                taskIdsForCallout.add(newTask.Id);
            }
        }

        // If there are tasks that meet the criteria, make the asynchronous callout.
        if (!taskIdsForCallout.isEmpty()) {
            // Pass the Set of Ids to the future method.
            // Future methods can only accept primitive types, collections of primitives, or SObject Ids.
            TaskCalloutService.sendRecordingUrls(taskIdsForCallout);
        }
    }
}