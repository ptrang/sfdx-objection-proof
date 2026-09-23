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

    // The API key lives in a protected custom setting so subscriber admins cannot
    // read it back from Setup; only package code can.
    public static String getApiKey() {
        return Secure_Setting__c.getOrgDefaults().Api_Key__c;
    }

    public static Boolean isApiKeyConfigured() {
        return String.isNotBlank(getApiKey());
    }

    public static void setApiKey(String apiKey) {
        Secure_Setting__c setting = Secure_Setting__c.getOrgDefaults();
        setting.Api_Key__c = apiKey;
        upsert setting;
    }

    public static Boolean getBoolean(String settingName) {
        String value = getString(settingName, 'false');
        return 'true'.equalsIgnoreCase(value);
    }
}