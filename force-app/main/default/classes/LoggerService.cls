public with sharing class LoggerService {

    // By making this variable @TestVisible, our test class can set it directly.
    @TestVisible
    private static Boolean isLoggingEnabled;

    // Use a static block to query the setting once per transaction.
    // This runs in normal execution but can be bypassed by the test.
    static {
        // We check if we are in a test context. If not, we query the setting.
        if (!Test.isRunningTest()) {
            try {
                Log_Configuration__mdt config = [
                    SELECT Logging_Enabled__c
                    FROM Log_Configuration__mdt
                    WHERE DeveloperName = 'Default'
                    LIMIT 1
                ];
                isLoggingEnabled = (config != null && config.Logging_Enabled__c);
            } catch (QueryException e) {
                // If the query fails for any reason, default to logging being off.
                isLoggingEnabled = false;
                System.debug('LoggerService static init failed: ' + e.getMessage());
            }
        }
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
        // Now, this check uses the value set by the test or by the static block.
        if (isLoggingEnabled != true) { // Explicitly check for true
            return;
        }

        if (logs == null || logs.isEmpty()) {
            return;
        }

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