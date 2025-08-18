@isTest
private class TaskCalloutServiceTest {

    // Mock implementation for the callout
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // VERIFY: These assertions check that the callout is being made correctly
            System.assertEquals('callout:objproof_namedcred', req.getEndpoint());
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getBody() != null);

            // Create a fake success response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"ok"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testSendRecordingUrlsCallout() {
        // SETUP
        Task testTask = new Task(
            Subject = 'Test Task for Callout',
            op_recording_url__c = 'https://example.com/recording/12345',
            op_callback_token__c = 'VALID-TOKEN-FOR-TEST'
        );
        insert testTask;

        // Set the mock callout that contains our assertions
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // EXECUTE
        Test.startTest();
        TaskCalloutService.sendRecordingUrls(new Set<Id>{testTask.Id});
        Test.stopTest();

        // No final assertion is needed here because the assertions are
        // in the mock response generator. If the callout is not made
        // as expected, those assertions will cause the test to fail.
    }
}