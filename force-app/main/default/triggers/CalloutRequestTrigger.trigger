trigger CalloutRequestTrigger on Callout_Request__e (after insert) {
    Set<Id> taskIds = new Set<Id>();
    String siteUrl; // Assume all events in a batch will have the same site URL

    for (Callout_Request__e event : Trigger.new) {
        taskIds.add(event.Task_ID__c);
        if (siteUrl == null) {
            siteUrl = event.Secure_Site_URL__c;
        }
    }

    if (!taskIds.isEmpty() && siteUrl != null) {
        // Enqueue a single job to process all tasks from this batch of events.
        System.enqueueJob(new TaskCalloutService(taskIds, siteUrl));
    }
}