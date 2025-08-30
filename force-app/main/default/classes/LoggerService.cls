public with sharing class LoggerService {

    @TestVisible
    private static Boolean isLoggingEnabled;

    static {
        // This logic now runs only in a non-test context.
        if (!Test.isRunningTest()) {
            List<Log_Configuration__mdt> configs = [
                SELECT Logging_Enabled__c
                FROM Log_Configuration__mdt
                LIMIT 1
            ];
            // If a record exists and is enabled, turn logging on. Otherwise, it's off.
            isLoggingEnabled = (!configs.isEmpty() && configs[0].Logging_Enabled__c);
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
        // The check now uses the static variable, which is safely initialized.
        if (isLoggingEnabled != true) {
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