@IsTest
private class TaskCallbackServiceTest {

    @TestSetup
    static void makeData() {
        // Create a Task with a valid callback token to be found by the service.
        Task t = new Task(
            Subject = 'Test for callback',
            op_callback_token__c = 'VALID-TOKEN-123'
        );
        insert t;

        // Create a Task that has already been processed.
        Task t2 = new Task(
            Subject = 'Already processed task',
            op_callback_token__c = 'USED-TOKEN-456',
            op_call_score__c = 99
        );
        insert t2;
    }

    @IsTest
    static void testSuccessfulUpdate() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/v1/task-callback/VALID-TOKEN-123';
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf('{"score": 88.5, "status": "processed"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        TaskCallbackService.updateTaskScore();
        Test.stopTest();

        System.assertEquals(204, res.statusCode);

        // Verify the record was updated correctly
        Task updatedTask = [SELECT op_call_score__c, op_callback_token__c FROM Task WHERE op_callback_token__c = NULL AND Subject = 'Test for callback' LIMIT 1];
        System.assertEquals(88.5, updatedTask.op_call_score__c);
        System.assertEquals(null, updatedTask.op_callback_token__c, 'Token should be nullified after use.');
    }

    @IsTest
    static void testInvalidToken() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/v1/task-callback/FAKE-TOKEN-789';
        req.httpMethod = 'PATCH';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        TaskCallbackService.updateTaskScore();
        Test.stopTest();

        System.assertEquals(404, res.statusCode);
    }

    @IsTest
    static void testAlreadyUsedToken() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/v1/task-callback/USED-TOKEN-456';
        req.httpMethod = 'PATCH';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        TaskCallbackService.updateTaskScore();
        Test.stopTest();

        System.assertEquals(410, res.statusCode);
    }
}