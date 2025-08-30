public with sharing class SettingsService {

    // This map is now @TestVisible, allowing test classes to populate it directly.
    @TestVisible
    private static Map<String, Application_Setting__mdt> settingsMap;

    static {
        // Only query the database if we are NOT running a test and the map hasn't been set.
        if (!Test.isRunningTest()) {
            settingsMap = new Map<String, Application_Setting__mdt>();
            for (Application_Setting__mdt setting : [SELECT DeveloperName, Value__c FROM Application_Setting__mdt]) {
                settingsMap.put(setting.DeveloperName, setting);
            }
        } else {
            // In a test context, initialize an empty map to prevent null pointer exceptions.
            settingsMap = new Map<String, Application_Setting__mdt>();
        }
    }

    public static String getString(String settingName, String defaultValue) {
        if (settingsMap != null && settingsMap.containsKey(settingName)) {
            return settingsMap.get(settingName).Value__c;
        }
        return defaultValue;
    }

    public static Boolean getBoolean(String settingName) {
        String value = getString(settingName, 'false');
        return 'true'.equalsIgnoreCase(value);
    }
}