public with sharing class LoggerService {

    // Asynchronous method for logging from synchronous contexts (e.g., triggers)
    @future
    private static void createLogsAsync(String logsAsJson) {
        insertLogsNow(logsAsJson);
    }

    // Synchronous, reusable DML operation
    private static void insertLogsNow(String logsAsJson) {
        try {
            List<Log__c> logsToInsert = (List<Log__c>) JSON.deserialize(logsAsJson, List<Log__c>.class);
            if (logsToInsert != null && !logsToInsert.isEmpty()) {
                // Use allOrNone=false to prevent one bad log from stopping others.
                Database.insert(logsToInsert, false);
            }
        } catch (Exception e) {
            // If logging itself fails, write to the debug log as a last resort.
            System.debug('LoggerService.insertLogsNow FAILED: ' + e.getMessage());
        }
    }

    // Overloaded method for convenience
    public static void log(String level, String message, String context) {
        log(new List<Log__c>{
            new Log__c(
                // IMPORTANT: Added the namespace prefix to custom fields
                objectionproof__Level__c = level,
                objectionproof__Message__c = message,
                objectionproof__Context__c = context
            )
        });
    }
    
    // Main logging method that decides which path to take
    public static void log(List<Log__c> logs) {
        if (logs == null || logs.isEmpty()) {
            return;
        }

        String logsAsJson = JSON.serialize(logs);

        // Check the context to decide how to insert the logs
        if (System.isFuture() || System.isBatch() || System.isQueueable()) {
            // If already in an async context, perform DML directly.
            insertLogsNow(logsAsJson);
        } else {
            // If in a sync context (like a trigger), use a future method to avoid errors.
            createLogsAsync(logsAsJson);
        }
    }
}