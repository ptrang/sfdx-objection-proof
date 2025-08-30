@isTest
private class TaskCalloutServiceTest {

    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('callout:objectionproof__objproof_namedcred', req.getEndpoint());
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getBody() != null);
            HttpResponse res = new HttpResponse();
            res.setBody('{"status":"ok"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testSendRecordingUrlsCallout() {
        Task testTask = new Task(
            Subject = 'Test Task for Callout',
            objectionproof__op_recording_url__c = 'https://example.com/recording/12345',
            objectionproof__op_callback_token__c = 'VALID-TOKEN-FOR-TEST'
        );
        insert testTask;

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        // Enqueue the Queueable job, passing the required parameters.
        System.enqueueJob(new TaskCalloutService(new Set<Id>{testTask.Id}, 'https://test.my.salesforce.com'));
        Test.stopTest();

        // The assertions in the mock are executed when the job runs.
        // No further assertions are needed here.
    }
}