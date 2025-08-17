@IsTest
private class TaskTriggerHandlerTest {

    @isTest
    static void testUpdateToNonRecordingField() {
        // SETUP: Create a task that already has a recording URL and a token.
        Task testTask = new Task(
            Subject = 'Initial Subject',
            op_recording_url__c = 'http://example.com/initial',
            op_callback_token__c = 'INITIAL-TOKEN'
        );
        insert testTask;

        // Create representations of the record before and after the update.
        Task oldTask = testTask.clone();
        Task updatedTask = testTask.clone();
        updatedTask.Subject = 'New Subject'; // Update a field that is NOT the recording URL.

        // EXECUTE the handler logic directly.
        Test.startTest();
        // The before-update logic should not generate a new token.
        TaskTriggerHandler.onBeforeUpdate(
            new List<Task>{ updatedTask },
            new Map<Id, Task>{ oldTask.Id => oldTask }
        );
        Test.stopTest();

        // VERIFY
        // The token should not have been changed because the recording URL was not changed.
        System.assertEquals('INITIAL-TOKEN', updatedTask.op_callback_token__c,
            'Token should not change when a non-URL field is updated.');
    }

    @isTest
    static void testInitialUrlPopulation() {
        // SETUP: Create a task without a URL.
        Task testTask = new Task(Subject = 'Initial Subject');
        insert testTask;

        Task oldTask = testTask.clone();
        Task updatedTask = testTask.clone();
        updatedTask.op_recording_url__c = 'http://example.com/new-url';

        // EXECUTE the before-update logic.
        Test.startTest();
        TaskTriggerHandler.onBeforeUpdate(
            new List<Task>{ updatedTask },
            new Map<Id, Task>{ oldTask.Id => oldTask }
        );
        Test.stopTest();

        // VERIFY
        // A new token should have been generated.
        System.assertNotEquals(null, updatedTask.op_callback_token__c,
            'A new token should be generated when the URL is first populated.');
    }
}