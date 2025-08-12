@RestResource(urlMapping='/v1/task-callback/*')
global with sharing class TaskCallbackService {
    // ... Inner class is the same ...

    @HttpPatch
    global static void updateTaskScore() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        String token = request.requestURI.substring(request.requestURI.lastIndexOf('/') + 1);

        // Find the task using the namespaced unique field.
        List<Task> tasks = [
            SELECT Id, objectionproof__call_score__c
            FROM Task
            WHERE objectionproof__callback_token__c = :token LIMIT 1
        ];

        if (tasks.isEmpty()) { /* ... 404 error ... */ return; }

        Task taskToUpdate = tasks[0];
        if (taskToUpdate.objectionproof__call_score__c != null) { /* ... 410 error ... */ return; }

        try {
            ScorePayload payload = (ScorePayload) JSON.deserialize(request.requestBody.toString(), ScorePayload.class);
            
            // Update the namespaced fields.
            taskToUpdate.objectionproof__call_score__c = payload.score;
            taskToUpdate.objectionproof__callback_token__c = null; // Invalidate token

            update taskToUpdate;

            response.statusCode = 204;
        } catch (Exception e) { /* ... 400 error ... */ }
    }
}