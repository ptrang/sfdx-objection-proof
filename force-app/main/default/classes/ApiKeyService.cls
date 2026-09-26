// Lets Objection Proof update this org's API key after rotating it.
//
// Called over OAuth (the Objection_Proof_AI external client app) as the
// integration user; only objproof_integration_permission_set grants this class.
// The caller must also prove it knows the key currently stored here: holding a
// valid token alone can't replace the key.
@RestResource(urlMapping='/v1/api-key')
global with sharing class ApiKeyService {

    private class KeyChange {
        public String current_api_key;
        public String new_api_key;
    }

    @HttpPost
    global static void rotate() {
        RestResponse response = RestContext.response;
        KeyChange body;
        try {
            body = (KeyChange) JSON.deserialize(RestContext.request.requestBody.toString(), KeyChange.class);
        } catch (Exception e) {
            respond(response, 400, 'Invalid request body.');
            return;
        }

        String newKey = body?.new_api_key == null ? null : body.new_api_key.trim();
        if (String.isBlank(body?.current_api_key) || String.isBlank(newKey) || newKey.length() > 255) {
            respond(response, 400, 'current_api_key and new_api_key are required (new_api_key up to 255 characters).');
            return;
        }

        String stored = SettingsService.getApiKey();
        if (String.isBlank(stored)) {
            respond(response, 409, 'API key is not configured in this org.');
            return;
        }
        // Idempotent: a retried push after a successful one is not an error.
        if (sameKey(stored, newKey)) {
            response.statusCode = 200;
            response.responseBody = Blob.valueOf('{"unchanged":true}');
            return;
        }
        if (!sameKey(stored, body.current_api_key.trim())) {
            respond(response, 403, 'Current API key does not match.');
            return;
        }

        SettingsService.setApiKey(newKey);
        LoggerService.log('INFO', 'Objection Proof API key was rotated by Objection Proof.', 'ApiKeyService.rotate');
        response.statusCode = 204;
    }

    // Compares SHA-256 digests, so response timing reveals nothing about the key.
    private static Boolean sameKey(String a, String b) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(a)))
            .equals(EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(b))));
    }

    private static void respond(RestResponse response, Integer status, String message) {
        response.statusCode = status;
        response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ 'error' => message }));
    }
}
