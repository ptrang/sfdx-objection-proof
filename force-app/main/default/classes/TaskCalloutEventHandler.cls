public class TaskCalloutEventHandler {

    public static void handleEvents(List<TaskCalloutEvent__e> events) {
        Set<Id> taskIds = new Set<Id>();
        String orgUrl = '';

        for (TaskCalloutEvent__e event : events) {
            taskIds.add((Id) event.TaskId__c);
            if (String.isBlank(orgUrl)) {
                orgUrl = event.OrgUrl__c;
            }
        }

        if (!taskIds.isEmpty()) {
            System.enqueueJob(new TaskCalloutService(taskIds, orgUrl));
        }
    }
}
