public with sharing class LoggerService {

    private static Boolean isLoggingEnabled;

    // Use a static block to query the setting once per transaction.
    // This is highly efficient as it's cached.
    static {
        Log_Configuration__mdt config = [
            SELECT Logging_Enabled__c
            FROM Log_Configuration__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        isLoggingEnabled = (config != null && config.Logging_Enabled__c);
    }

    @future
    private static void createLogsAsync(String logsAsJson) {
        insertLogsNow(logsAsJson);
    }

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
    
    public static void log(String level, String message, String context) {
        log(new List<Log__c>{
            new Log__c(
                objectionproof__Level__c = level,
                objectionproof__Message__c = message,
                objectionproof__Context__c = context
            )
        });
    }
    
    public static void log(List<Log__c> logs) {
        // Check the cached static variable.
        if (!isLoggingEnabled) {
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