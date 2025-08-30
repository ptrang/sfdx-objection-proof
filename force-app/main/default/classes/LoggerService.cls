public with sharing class LoggerService {

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

    @future
    private static void createLogsAsync(String logsAsJson) {
        insertLogsNow(logsAsJson);
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
        if (!SettingsService.getBoolean('Logging_Enabled')) {
            return;
        }
        if (logs == null || logs.isEmpty()) {
            return;
        }

        String logsAsJson = JSON.serialize(logs);

        if (Test.isRunningTest()) {
            insertLogsNow(logsAsJson);
        } else if (System.isFuture() || System.isBatch() || System.isQueueable()) {
            // This is now safe because it happens AFTER the callouts.
            insertLogsNow(logsAsJson);
        } else {
            createLogsAsync(logsAsJson);
        }
    }
}