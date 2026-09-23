@isTest
private class TaskCalloutServiceTest {

    private static String expectedSource = 'sf-bolder360';

    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('callout:objectionproof__objproof_namedcred', req.getEndpoint());
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getBody() != null);
            System.assertEquals('test-api-key', req.getHeader('ObjectionProof-Token'));
            System.assertEquals(UserInfo.getOrganizationId(), req.getHeader('Salesforce-Org-Id'));
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            System.assertEquals(expectedSource, (String) body.get('source'));
            System.assert(((String) body.get('callbackUrl')).endsWith('/task-callback/VALID-TOKEN-FOR-TEST'));
            HttpResponse res = new HttpResponse();
            res.setBody('{"status":"ok"}');
            res.setStatusCode(200);
            return res;
        }
    }

    private static Task insertTask() {
        Task testTask = new Task(
            Subject = 'Test Task for Callout',
            objectionproof__op_recording_url__c = 'https://example.com/recording/12345',
            objectionproof__op_callback_token__c = 'VALID-TOKEN-FOR-TEST'
        );
        insert testTask;
        return testTask;
    }

    @isTest
    static void testCalloutSourceFromSetting() {
        SettingsService.setApiKey('test-api-key');
        SettingsService.settingsMap.put('Callout_Source', new objectionproof__Application_Setting__mdt(
            DeveloperName = 'Callout_Source',
            objectionproof__Value__c = 'custom-source'
        ));
        expectedSource = 'custom-source';
        Task testTask = insertTask();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        System.enqueueJob(new TaskCalloutService(new Set<Id>{testTask.Id}, 'https://test.my.salesforce.com'));
        Test.stopTest();
    }

    @isTest
    static void testMissingApiKeyAborts() {
        Task testTask = insertTask();

        Test.startTest();
        // No mock registered: a callout attempt would fail the test.
        System.enqueueJob(new TaskCalloutService(new Set<Id>{testTask.Id}, 'https://test.my.salesforce.com'));
        Test.stopTest();
    }

    @isTest
    static void testSendRecordingUrlsCallout() {
        SettingsService.setApiKey('test-api-key');
        Task testTask = insertTask();

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        // Enqueue the Queueable job, passing the required parameters.
        System.enqueueJob(new TaskCalloutService(new Set<Id>{testTask.Id}, 'https://test.my.salesforce.com'));
        Test.stopTest();

        // The assertions in the mock are executed when the job runs.
        // No further assertions are needed here.
    }
}