@isTest
private class TaskCalloutServiceTest {

    // Mock implementation that now returns a JSON body with a score
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('callout:Recording_Service', req.getEndpoint());
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getBody() != null);

            // Create a fake response with the score
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            // This is the expected response from the external service
            res.setBody('{"score": 92.5}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testPostUrlAndUpdateScore() {
        Task testTask = new Task(
            Subject = 'Test Task for Callout',
            Status = 'Not Started'
        );
        insert testTask;

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        
        Task taskToUpdate = [SELECT Id, op_recording_url__c FROM Task WHERE Id = :testTask.Id];
        taskToUpdate.op_recording_url__c = 'https://example.com/recording/12345';
        // TaskCalloutService.sendRecordingUrls(new Set<Id>{testTask.Id});
        update taskToUpdate;
        
        Test.stopTest();

        // After Test.stopTest(), the future method has run.
        // We now query the task again to verify it was updated with the score from the mock response.
        Task resultTask = [SELECT Id, op_call_score__c FROM Task WHERE Id = :testTask.Id];

        System.assertEquals(92.5, resultTask.op_call_score__c,
            'The call score should be updated from the mock response.');
    }
}