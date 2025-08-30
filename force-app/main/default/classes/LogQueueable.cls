public class LogQueueable implements Queueable {

    private final String logsAsJson;

    public LogQueueable(String logsAsJson) {
        this.logsAsJson = logsAsJson;
    }

    public void execute(QueueableContext context) {
        try {
            List<Log__c> logsToInsert = (List<Log__c>) JSON.deserialize(logsAsJson, List<Log__c>.class);
            if (logsToInsert != null && !logsToInsert.isEmpty()) {
                // This DML now runs in its own safe, isolated transaction.
                Database.insert(logsToInsert, false);
            }
        } catch (Exception e) {
            // If the queueable fails, write to the debug log as a final fallback.
            System.debug('LogQueueable FAILED: ' + e.getMessage());
        }
    }
}