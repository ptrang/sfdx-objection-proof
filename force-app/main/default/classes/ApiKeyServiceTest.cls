@IsTest
private class ApiKeyServiceTest {

    private static RestResponse post(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/v1/api-key';
        req.httpMethod = 'POST';
        req.requestBody = body == null ? null : Blob.valueOf(body);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        ApiKeyService.rotate();
        return res;
    }

    private static String change(String current, String next) {
        return JSON.serialize(new Map<String, String>{ 'current_api_key' => current, 'new_api_key' => next });
    }

    @IsTest
    static void testRotatesWhenCurrentKeyMatches() {
        SettingsService.setApiKey('old-key');
        RestResponse res = post(change('old-key', '  new-key  '));
        System.assertEquals(204, res.statusCode);
        System.assertEquals('new-key', SettingsService.getApiKey(), 'New key should be trimmed and stored');
    }

    @IsTest
    static void testRefusesWrongCurrentKey() {
        SettingsService.setApiKey('old-key');
        RestResponse res = post(change('guessed-key', 'attacker-key'));
        System.assertEquals(403, res.statusCode);
        System.assertEquals('old-key', SettingsService.getApiKey(), 'Key must not change');
    }

    @IsTest
    static void testRetryAfterSuccessIsUnchanged() {
        SettingsService.setApiKey('new-key');
        RestResponse res = post(change('old-key', 'new-key'));
        System.assertEquals(200, res.statusCode);
        System.assert(res.responseBody.toString().contains('unchanged'));
    }

    @IsTest
    static void testNotConfigured() {
        RestResponse res = post(change('old-key', 'new-key'));
        System.assertEquals(409, res.statusCode);
        System.assertEquals(false, SettingsService.isApiKeyConfigured());
    }

    @IsTest
    static void testRejectsMissingFieldsAndBadJson() {
        SettingsService.setApiKey('old-key');
        System.assertEquals(400, post(change('old-key', '')).statusCode);
        System.assertEquals(400, post(change('', 'new-key')).statusCode);
        System.assertEquals(400, post(change('old-key', 'x'.repeat(256))).statusCode);
        System.assertEquals(400, post('{not json').statusCode);
        System.assertEquals('old-key', SettingsService.getApiKey());
    }

    @IsTest
    static void testErrorsNeverEchoKeys() {
        SettingsService.setApiKey('old-key');
        RestResponse res = post(change('guessed-key', 'attacker-key'));
        String body = res.responseBody.toString();
        System.assert(!body.contains('old-key') && !body.contains('guessed-key') && !body.contains('attacker-key'));
    }
}
