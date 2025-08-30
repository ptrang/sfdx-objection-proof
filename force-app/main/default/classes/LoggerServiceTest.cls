@isTest
private class LoggerServiceTest {

    // Helper method to enable logging for tests
    private static void enableTestLogging() {
        SettingsService.settingsMap.put('Logging_Enabled', new objectionproof__Application_Setting__mdt(
            objectionproof__Value__c = 'true'
        ));
    }

    @isTest
    static void testLoggingCreatesRecord() {
        enableTestLogging();

        // Act
        LoggerService.log('INFO', 'Test message from sync context', 'LoggerServiceTest.sync');

        // Assert: Because we are in a test, the insert happens synchronously.
        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(1, logs.size(), 'A log record should have been created.');
    }

    @isTest
    static void testLoggingWithList() {
        enableTestLogging();

        List<objectionproof__Log__c> logsToCreate = new List<objectionproof__Log__c>();
        logsToCreate.add(new objectionproof__Log__c(
            objectionproof__Level__c = 'WARN',
            objectionproof__Message__c = 'Warning message'
        ));
        logsToCreate.add(new objectionproof__Log__c(
            objectionproof__Level__c = 'ERROR',
            objectionproof__Message__c = 'Error message'
        ));
        
        // Act
        LoggerService.log(logsToCreate);

        // Assert
        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(2, logs.size(), 'Two log records should have been created.');
    }

    @isTest
    static void testLoggingWhenDisabled() {
        // Ensure logging is disabled (which it is by default in the test context)
        
        // Act
        LoggerService.log('ERROR', 'This should not be logged', 'LoggerServiceTest.disabled');

        // Assert
        List<objectionproof__Log__c> logs = [SELECT Id FROM objectionproof__Log__c];
        System.assertEquals(0, logs.size(), 'No log records should be created when logging is disabled.');
    }

    // --- NEW TEST METHOD ---
    @isTest
    static void testLoggingPopulatesTriggeringUser() {
        // Arrange: Create a specific test user to run the code as.
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User testUser = new User(
            Alias = 'testuser', 
            Email='testuser@example.com', 
            EmailEncodingKey='UTF-8', 
            LastName='Testing', 
            LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', 
            ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='testuser' + System.currentTimeMillis() + '@testorg.com'
        );
        insert testUser;

        // Act: Run the logging logic as the new test user.
        System.runAs(testUser) {
            enableTestLogging();
            LoggerService.log('INFO', 'Test message from a specific user', 'testRunAs');
        }

        // Assert: Verify that the log was created and correctly attributes the triggering user.
        List<objectionproof__Log__c> logs = [SELECT Id, objectionproof__Triggering_User__c FROM objectionproof__Log__c];
        System.assertEquals(1, logs.size(), 'A log record should have been created.');
        System.assertEquals(testUser.Id, logs[0].objectionproof__Triggering_User__c, 'The Triggering User on the log should match the user who ran the code.');
    }
}