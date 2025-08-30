@isTest
private class LoggerServiceTest {

    @isTest
    static void testLogFromSynchronousContext() {
        // --- CORRECTED ---
        // Inject the setting at the start of the test method, not in @TestSetup.
        SettingsService.settingsMap.put('Logging_Enabled', new objectionproof__Application_Setting__mdt(
            objectionproof__Value__c = 'true'
        ));

        Test.startTest();
        LoggerService.log('INFO', 'Test message from sync context', 'LoggerServiceTest.sync');
        Test.stopTest();

        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(1, logs.size(), 'A log record should have been created asynchronously.');
    }

    @isTest
    static void testLogFromAsynchronousContext() {
        // Inject the setting at the start of the test method.
        SettingsService.settingsMap.put('Logging_Enabled', new objectionproof__Application_Setting__mdt(
            objectionproof__Value__c = 'true'
        ));

        Test.startTest();
        System.enqueueJob(new AsyncLoggerTestJob());
        Test.stopTest();

        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(1, logs.size(), 'A log record should have been created synchronously from the async job.');
    }

    @isTest
    static void testLogWithList() {
        // Inject the setting at the start of the test method.
        SettingsService.settingsMap.put('Logging_Enabled', new objectionproof__Application_Setting__mdt(
            objectionproof__Value__c = 'true'
        ));
        
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