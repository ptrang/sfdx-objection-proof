public with sharing class LoggerService {

    @future
    public static void createLogs(String logsAsJson) {
        // Deserialize the JSON string back into a list of Log__c objects.
        List<Log__c> logsToInsert = (List<Log__c>) JSON.deserialize(logsAsJson, List<Log__c>.class);

        // Using Database.insert with allOrNone=false ensures that if some logs
        // fail to insert (e.g., due to validation rules in the subscriber org),
        // it won't prevent other logs from being saved.
        if (logsToInsert != null && !logsToInsert.isEmpty()) {
            Database.insert(logsToInsert, false);
        }
    }

    // Overloaded method for convenience - no changes needed here.
    public static void log(String level, String message, String context) {
        log(new List<Log__c>{
            new Log__c(
                Level__c = level,
                Message__c = message,
                Context__c = context
            )
        });
    }
    
    public static void log(List<Log__c> logs) {
        // By calling the @future method, we ensure that the logging DML operation
        // happens in a separate, asynchronous transaction. This prevents the dreaded
        // "Mixed DML" error if the main transaction is performing setup DML.
        // It also ensures that a logging failure can never roll back the primary transaction.
        if (logs != null && !logs.isEmpty() && !System.isFuture() && !System.isBatch()) {
            // Serialize the list into a JSON string before calling the future method.
            String logsAsJson = JSON.serialize(logs);
            createLogs(logsAsJson);
        }
    }
}