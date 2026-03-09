@isTest
private class LeadCalloutServiceTest {

    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assert(req.getEndpoint().contains('objproof_lead_namedcred'), 'Expected lead named credential endpoint');
            System.assertEquals('POST', req.getMethod());

            // Verify the body matches the call-lead API contract
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            System.assertEquals('test-api-key', (String) body.get('api_key'), 'Expected api_key in body');
            System.assert(String.isNotBlank((String) body.get('lead_phone')), 'Expected lead_phone in body');
            System.assertEquals('Test Lead', (String) body.get('full_name'), 'Expected full_name in body');

            HttpResponse res = new HttpResponse();
            res.setBody('{"success":true,"client_id":6,"data":{"message":"Workflow was started"}}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testSendLeadCallout() {
        // Inject the API key setting for the test context.
        SettingsService.settingsMap = new Map<String, Application_Setting__mdt>{
            'Lead_Api_Key' => new Application_Setting__mdt(
                DeveloperName = 'Lead_Api_Key',
                objectionproof__Value__c = 'test-api-key'
            )
        };

        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Email = 'test@example.com',
            Phone = '(555) 123-4567',
            Street = '123 Main St',
            City = 'Austin',
            State = 'TX',
            PostalCode = '78701',
            LeadSource = 'Web'
        );
        insert testLead;

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        System.enqueueJob(new LeadCalloutService(new Set<Id>{ testLead.Id }));
        Test.stopTest();
    }

    @isTest
    static void testMissingApiKeyAborts() {
        // No API key configured — should abort without making a callout.
        SettingsService.settingsMap = new Map<String, Application_Setting__mdt>();

        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Phone = '5551234567'
        );
        insert testLead;

        Test.startTest();
        System.enqueueJob(new LeadCalloutService(new Set<Id>{ testLead.Id }));
        Test.stopTest();

        // No callout should have been attempted — no mock needed.
    }

    @isTest
    static void testSkipsLeadWithNoPhone() {
        SettingsService.settingsMap = new Map<String, Application_Setting__mdt>{
            'Lead_Api_Key' => new Application_Setting__mdt(
                DeveloperName = 'Lead_Api_Key',
                objectionproof__Value__c = 'test-api-key'
            )
        };

        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company'
            // No Phone or MobilePhone
        );
        insert testLead;

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        System.enqueueJob(new LeadCalloutService(new Set<Id>{ testLead.Id }));
        Test.stopTest();

        // Lead should be skipped — no callout made.
    }

    @isTest
    static void testMissingLeadLogsWarning() {
        SettingsService.settingsMap = new Map<String, Application_Setting__mdt>{
            'Lead_Api_Key' => new Application_Setting__mdt(
                DeveloperName = 'Lead_Api_Key',
                objectionproof__Value__c = 'test-api-key'
            )
        };

        // Use a fake Lead Id that won't exist in the database.
        Id fakeLeadId = Lead.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        System.enqueueJob(new LeadCalloutService(new Set<Id>{ fakeLeadId }));
        Test.stopTest();

        // No exception should be thrown; the missing lead is logged as a warning.
    }
}
