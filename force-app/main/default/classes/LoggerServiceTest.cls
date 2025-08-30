@isTest
private class LoggerServiceTest {

    @isTest
    static void testLogFromSynchronousContext() {
        Test.startTest();

        // Call the logger from a standard (synchronous) test method.
        LoggerService.log('INFO', 'Test message from sync context', 'LoggerServiceTest.sync');
        
        Test.stopTest(); // This executes the @future method.

        // Verify that one log record was created.
        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(1, logs.size(), 'A log record should have been created asynchronously.');
    }

    @isTest
    static void testLogFromAsynchronousContext() {
        Test.startTest();

        // To test logging from an async context, we enqueue a simple Queueable job
        // that calls the logger.
        System.enqueueJob(new AsyncLoggerTestJob());
        
        Test.stopTest(); // This executes the Queueable job.

        // Verify that one log record was created.
        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(1, logs.size(), 'A log record should have been created synchronously from the async job.');
    }

    @isTest
    static void testLogWithList() {
        List<objectionproof__Log__c> logsToCreate = new List<objectionproof__Log__c>();
        logsToCreate.add(new objectionproof__Log__c(
            objectionproof__Level__c = 'WARN',
            objectionproof__Message__c = 'Warning message',
            objectionproof__Context__c = 'LoggerServiceTest.list'
        ));
        logsToCreate.add(new objectionproof__Log__c(
            objectionproof__Level__c = 'ERROR',
            objectionproof__Message__c = 'Error message',
            objectionproof__Context__c = 'LoggerServiceTest.list'
        ));

        Test.startTest();
        LoggerService.log(logsToCreate);
        Test.stopTest();

        // Verify that two log records were created.
        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(2, logs.size(), 'Two log records should have been created.');
    }
    
    @isTest
    static void testLogWithNullAndEmptyList() {
        Test.startTest();

        // Call the logger with null and empty lists.
        // No exceptions should be thrown.
        LoggerService.log((List<objectionproof__Log__c>) null);
        LoggerService.log(new List<objectionproof__Log__c>());

        Test.stopTest();

        // Verify that no log records were created.
        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(0, logs.size(), 'No log records should be created for null or empty lists.');
    }

    // Helper class to simulate running code in an asynchronous context.
    public class AsyncLoggerTestJob implements Queueable {
        public void execute(QueueableContext context) {
            // This code runs inside an async transaction, so LoggerService
            // should perform a direct, synchronous insert.
            LoggerService.log('DEBUG', 'Test message from async context', 'AsyncLoggerTestJob');
        }
    }
}