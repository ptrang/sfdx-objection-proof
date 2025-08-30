public with sharing class LoggerService {

    // Asynchronous method for logging from synchronous contexts
    @future
    private static void createLogsAsync(String logsAsJson) {
        insertLogsNow(logsAsJson);
    }

    // Synchronous, reusable DML operation
    private static void insertLogsNow(String logsAsJson) {
        try {
            List<Log__c> logsToInsert = (List<Log__c>) JSON.deserialize(logsAsJson, List<Log__c>.class);
            if (logsToInsert != null && !logsToInsert.isEmpty()) {
                Database.insert(logsToInsert, false);
            }
        } catch (Exception e) {
            System.debug('LoggerService.insertLogsNow FAILED: ' + e.getMessage());
        }
    }

    // Overloaded method for convenience
    public static void log(String level, String message, String context) {
        log(new List<Log__c>{
            new Log__c(
                objectionproof__Level__c = level,
                objectionproof__Message__c = message,
                objectionproof__Context__c = context
            )
        });
    }
    
    // Main logging method that decides which path to take
    public static void log(List<Log__c> logs) {
        Logging_Settings__c settings = Logging_Settings__c.getInstance();

        // If no setting record exists, settings.Logging_Enabled__c will be false
        // because that is the field's default value.
        // Therefore, we only proceed if the setting is explicitly true.
        if (settings == null || !settings.Logging_Enabled__c) {
            return;
        }

        if (logs == null || logs.isEmpty()) {
            return;
        }

        String logsAsJson = JSON.serialize(logs);

        if (System.isFuture() || System.isBatch() || System.isQueueable()) {
            insertLogsNow(logsAsJson);
        } else {
            createLogsAsync(logsAsJson);
        }
    }
}