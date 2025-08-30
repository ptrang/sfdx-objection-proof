@isTest
private class SettingsServiceTest {

    @isTest
    static void testGetBooleanSetting_True() {
        // Arrange: Inject a setting with a 'true' value.
        SettingsService.settingsMap.put('Test_Boolean', new objectionproof__Application_Setting__mdt(
            objectionproof__Value__c = 'true'
        ));

        // Act
        Boolean result = SettingsService.getBoolean('Test_Boolean');

        // Assert
        System.assertEquals(true, result, 'The boolean value should be true.');
    }

    @isTest
    static void testGetBooleanSetting_False() {
        // Arrange: Inject a setting with a 'false' value.
        SettingsService.settingsMap.put('Test_Boolean', new objectionproof__Application_Setting__mdt(
            objectionproof__Value__c = 'false'
        ));

        // Act
        Boolean result = SettingsService.getBoolean('Test_Boolean');

        // Assert
        System.assertEquals(false, result, 'The boolean value should be false.');
    }
    
    @isTest
    static void testGetStringSetting() {
        // Arrange
        String expectedValue = 'https://example.com/api';
        SettingsService.settingsMap.put('Test_String', new objectionproof__Application_Setting__mdt(
            objectionproof__Value__c = expectedValue
        ));
        
        // Act
        String result = SettingsService.getString('Test_String', 'default');

        // Assert
        System.assertEquals(expectedValue, result, 'The string value should be retrieved correctly.');
    }

    @isTest
    static void testGetSetting_DefaultValue() {
        // Arrange: No setting is injected for 'Non_Existent_Setting'.
        
        // Act
        String result = SettingsService.getString('Non_Existent_Setting', 'default-value');
        Boolean boolResult = SettingsService.getBoolean('Non_Existent_Boolean');

        // Assert
        System.assertEquals('default-value', result, 'The default string value should be returned.');
        System.assertEquals(false, boolResult, 'The default boolean value should be false.');
    }
}