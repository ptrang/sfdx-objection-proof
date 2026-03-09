@isTest
private class LeadCalloutEventHandlerTest {

    @isTest
    static void testHandleEventsEnqueuesJob() {
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company'
        );
        insert testLead;

        LeadCalloutEvent__e event = new LeadCalloutEvent__e(
            LeadId__c = testLead.Id
        );

        Test.startTest();
        EventBus.publish(event);
        Test.getEventBus().deliver();

        // Verify that a Queueable job was enqueued.
        List<AsyncApexJob> jobs = [
            SELECT Id, ApexClass.Name FROM AsyncApexJob
            WHERE ApexClass.Name = 'LeadCalloutService'
            AND Status IN ('Queued', 'Holding', 'Preparing')
        ];
        System.assertEquals(1, jobs.size(), 'Expected one LeadCalloutService job to be enqueued.');
        Test.stopTest();
    }
}
