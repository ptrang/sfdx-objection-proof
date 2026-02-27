@isTest
private class TaskCalloutEventHandlerTest {

    @isTest
    static void testHandleEventsEnqueuesCallout() {
        Task t = new Task(Subject = 'Test Call Recording');
        insert t;

        TaskCalloutEvent__e event = new TaskCalloutEvent__e(
            TaskId__c = t.Id,
            OrgUrl__c = URL.getOrgDomainUrl().toExternalForm()
        );

        Test.startTest();
        EventBus.publish(event);
        Test.getEventBus().deliver();

        Integer queuedJobs = [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = 'TaskCalloutService'
            AND Status = 'Queued'
        ];
        System.assertEquals(1, queuedJobs, 'TaskCalloutService should be enqueued after event delivery.');

        Test.stopTest();
    }

    @isTest
    static void testHandleEventsIgnoresEmptyBatch() {
        Test.startTest();
        // Pass empty list - should not throw or enqueue anything
        TaskCalloutEventHandler.handleEvents(new List<TaskCalloutEvent__e>());
        Test.stopTest();

        Integer queuedJobs = [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = 'TaskCalloutService'
        ];
        System.assertEquals(0, queuedJobs, 'No job should be enqueued for an empty event list.');
    }
}
