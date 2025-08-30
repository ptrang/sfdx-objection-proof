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
        
        // --- UPDATED: Provide a full payload for the test ---
        String testPayload = '{' +
            '"salescall_id": "ext-id-123",' +
            '"transcript": "This is the call transcript...",' +
            '"evaluation": "This was a good call...",' +
            '"opening": 9.1,' +
            '"engagement": 8.2,' +
            '"nonneedy": 7.3,' +
            '"guiding": 6.4,' +
            '"closing": 9.5,' +
            '"assertiveness": 8.6,' +
            '"empathy": 7.7,' +
            '"stories": 6.8,' +
            '"objection": 9.9,' +
            '"remorse": 8.0,' +
            '"score": 95.5' +
        '}';
        req.requestBody = Blob.valueOf(testPayload);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        TaskCallbackService.updateTaskScore();
        Test.stopTest();

        System.assertEquals(204, res.statusCode, 'Status code should be 204 for a successful update.');

        // --- UPDATED: Verify all new fields are updated correctly ---
        Task updatedTask = [
            SELECT objectionproof__op_salescall_id__c, objectionproof__op_transcript__c, objectionproof__op_evaluation__c,
                   objectionproof__op_call_revenue__c, objectionproof__op_call_score_opening__c, objectionproof__op_call_score__c
            FROM Task WHERE objectionproof__op_callback_token__c = NULL AND Subject = 'Test for callback' LIMIT 1
        ];
        
        System.assertEquals('ext-id-123', updatedTask.objectionproof__op_salescall_id__c);
        System.assertEquals(9.1, updatedTask.objectionproof__op_call_score_opening__c);
        System.assertEquals(95.5, updatedTask.objectionproof__op_call_score__c);
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

    // NEW TEST: Covers the case where the callback body is malformed.
    @isTest
    static void testCallbackWithInvalidJsonBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/v1/task-callback/VALID-TOKEN-123';
        req.httpMethod = 'PATCH';
        // Send a malformed JSON string
        req.requestBody = Blob.valueOf('{"score": not_a_number}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        TaskCallbackService.updateTaskScore();
        Test.stopTest();

        // We expect the service to identify the bad request and return a 400 status code.
        System.assertEquals(400, res.statusCode, 'Status code should be 400 for a bad request.');
    }
}