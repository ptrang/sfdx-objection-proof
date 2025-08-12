public with sharing class TaskCalloutService {

    @future(callout=true)
    public static void sendRecordingUrls(Set<Id> taskIds) {
        List<Task> tasksToSend = [SELECT Id, recording_url__c FROM Task WHERE Id IN :taskIds];
        List<Task> tasksToUpdateWithScore = new List<Task>();

        for (Task task : tasksToSend) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Recording_Service');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json;charset=UTF-8');

            Map<String, String> bodyMap = new Map<String, String>{
                'taskId' => task.Id,
                'recordingUrl' => task.recording_url__c
            };
            req.setBody(JSON.serialize(bodyMap));

            Http http = new Http();
            try {
                HttpResponse res = http.send(req);

                // If the callout is successful, parse the response and prepare the Task for update.
                if (res.getStatusCode() == 200) {
                    System.debug('Callout successful for Task Id: ' + task.Id + '. Body: ' + res.getBody());
                    
                    // Safely parse the response and update the task
                    try {
                        Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                        
                        // Check if the 'score' key exists and is a number
                        if (results.containsKey('score') && results.get('score') instanceOf Decimal) {
                            Decimal score = (Decimal) results.get('score');
                            tasksToUpdateWithScore.add(new Task(Id = task.Id, call_score__c = score));
                        } else {
                             System.debug(LoggingLevel.WARN, 'Callout response for Task ' + task.Id + ' did not contain a valid score.');
                        }
                    } catch (Exception e) {
                        System.debug(LoggingLevel.ERROR, 'Failed to parse callout response for Task Id: ' + task.Id + '. Error: ' + e.getMessage());
                    }

                } else {
                    System.debug(LoggingLevel.ERROR, 'Callout failed for Task Id: ' + task.Id + '. Status: ' + res.getStatus() + '. Status Code: ' + res.getStatusCode() + '. Body: ' + res.getBody());
                }
            } catch (System.CalloutException e) {
                System.debug(LoggingLevel.ERROR, 'Callout exception for Task Id: ' + task.Id + '. Error: ' + e.getMessage());
            }
        }

        // After the loop, perform a single DML update for all tasks that received a score.
        // This is bulkified and efficient.
        if (!tasksToUpdateWithScore.isEmpty()) {
            try {
                update tasksToUpdateWithScore;
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'Failed to update Tasks with scores. Error: ' + e.getMessage());
            }
        }
    }
}