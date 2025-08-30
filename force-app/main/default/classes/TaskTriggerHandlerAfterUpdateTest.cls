@isTest
private class TaskTriggerHandlerAfterUpdateTest {

    @TestSetup
    static void makeData() {
        // Create a Task record that will be updated by the test method.
        Task t = new Task(
            Subject = 'Test for After Update',
            objectionproof__op_recording_url__c = 'http://example.com/initial'
        );
        insert t;
    }

    @isTest
    static void testAfterUpdateFiresCallout() {
        // Arrange: Enable logging to ensure that part of the code runs.
        SettingsService.settingsMap.put('Logging_Enabled', new objectionproof__Application_Setting__mdt(
            objectionproof__Value__c = 'true'
        ));
        
        Task testTask = [SELECT Id, objectionproof__op_callback_token__c FROM Task LIMIT 1];
        System.assertEquals(null, testTask.objectionproof__op_callback_token__c, 'Token should be null initially.');

        Test.startTest();

        // Act: Fire the trigger by populating the callback token,
        // which simulates the state after a "before update" trigger has run.
        testTask.objectionproof__op_callback_token__c = 'TEST-TOKEN-123';
        update testTask;
        
        Test.stopTest(); // This will execute the future callout.

        // Assert: We can't directly verify the callout was made, but we can
        // verify that the trigger executed without throwing an error by querying
        // for the log records that should have been created by the handler.
        List<objectionproof__Log__c> logs = [SELECT Id, objectionproof__Message__c FROM objectionproof__Log__c WHERE objectionproof__Context__c = 'TaskTriggerHandler.makeCallout'];
        System.assertEquals(1, logs.size(), 'One log record should be created by the makeCallout method.');
        System.assert(logs[0].objectionproof__Message__c.contains('Successfully enqueued TaskCalloutService job'), 'The log should indicate success.');
    }
}