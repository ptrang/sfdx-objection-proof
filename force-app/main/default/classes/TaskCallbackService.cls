@RestResource(urlMapping='/v1/task-callback/*')
global with sharing class TaskCallbackService {

    // Helper class to parse the incoming JSON body
    private class ScorePayload {
        public Decimal score { get; set; }
        public String status { get; set; }
    }

    @HttpPatch
    global static void updateTaskScore() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;

        // Extract the token from the URL. e.g., .../v1/task-callback/A_B_C_TOKEN
        String token = request.requestURI.substring(request.requestURI.lastIndexOf('/') + 1);

        // Find the task using the unique, case-sensitive token.
        List<Task> tasks = [SELECT Id, op_call_score__c FROM Task WHERE op_callback_token__c = :token LIMIT 1];

        if (tasks.isEmpty()) {
            response.statusCode = 404; // Not Found
            response.responseBody = Blob.valueOf('{"error":"Invalid or expired token "' + token + '"."}');
            return;
        }

        Task taskToUpdate = tasks[0];

        // If the score is already set, the token was likely already used.
        if (taskToUpdate.op_call_score__c != null) {
            response.statusCode = 410; // Gone (already processed)
            response.responseBody = Blob.valueOf('{"error":"This callback has already been processed."}');
            return;
        }

        try {
            ScorePayload payload = (ScorePayload) JSON.deserialize(
                request.requestBody.toString(),
                ScorePayload.class
            );

            taskToUpdate.op_call_score__c = payload.score;
            // CRITICAL: Invalidate the token to make it single-use.
            taskToUpdate.op_callback_token__c = null;

            update taskToUpdate;

            response.statusCode = 204; // No Content (Success with no body to return)

        } catch (Exception e) {
            response.statusCode = 400; // Bad Request
            response.responseBody = Blob.valueOf('{"error":"Invalid request body.", "details":"' + e.getMessage() + '"}');
        }
    }
}