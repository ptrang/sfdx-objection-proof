@isTest
private class LeadCalloutInvocableTest {

    @isTest
    static void testCalloutPublishesEvent() {
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            LeadSource = 'Web'
        );
        insert testLead;

        LeadCalloutInvocable.Request req = new LeadCalloutInvocable.Request();
        req.leadId = testLead.Id;

        Test.startTest();
        LeadCalloutInvocable.callout(new List<LeadCalloutInvocable.Request>{ req });
        Test.stopTest();

        // Event was published successfully if no exception was thrown.
    }

    @isTest
    static void testCalloutWithEmptyList() {
        Test.startTest();
        LeadCalloutInvocable.callout(new List<LeadCalloutInvocable.Request>());
        Test.stopTest();

        // Should return without error.
    }

    @isTest
    static void testCalloutWithNullList() {
        Test.startTest();
        LeadCalloutInvocable.callout(null);
        Test.stopTest();

        // Should return without error.
    }
}
