@isTest
private class LoggerServiceTest {

    @isTest
    static void testLogFromSynchronousContext() {
        // --- NEW ---
        // Directly enable logging for the context of this test.
        LoggerService.isLoggingEnabled = true;

        Test.startTest();
        LoggerService.log('INFO', 'Test message from sync context', 'LoggerServiceTest.sync');
        Test.stopTest();

        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(1, logs.size(), 'A log record should have been created asynchronously.');
    }

    @isTest
    static void testLogFromAsynchronousContext() {
        // Enable logging for the test.
        LoggerService.isLoggingEnabled = true;

        Test.startTest();
        System.enqueueJob(new AsyncLoggerTestJob());
        Test.stopTest();

        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(1, logs.size(), 'A log record should have been created synchronously from the async job.');
    }

    @isTest
    static void testLogWithList() {
        // Enable logging for the test.
        LoggerService.isLoggingEnabled = true;
        
        List<objectionproof__Log__c> logsToCreate = new List<objectionproof__Log__c>();
        logsToCreate.add(new objectionproof__Log__c(
            objectionproof__Level__c = 'WARN',
            objectionproof__Message__c = 'Warning message',
            objectionproof__Context__c = 'LoggerServiceTest.list'
        ));
        
        Test.startTest();
        LoggerService.log(logsToCreate);
        Test.stopTest();

        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(1, logs.size(), 'One log record should have been created.');
    }
    
    // Helper class to simulate running code in an asynchronous context.
    public class AsyncLoggerTestJob implements Queueable {
        public void execute(QueueableContext context) {
            LoggerService.log('DEBUG', 'Test message from async context', 'AsyncLoggerTestJob');
        }
    }
}