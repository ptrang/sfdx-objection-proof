@IsTest
private class OrgRegistrationServiceTest {

    private class RegisterMock implements HttpCalloutMock {
        Integer calls = 0;
        Integer status;
        RegisterMock(Integer status) { this.status = status; }
        public HttpResponse respond(HttpRequest req) {
            calls++;
            System.assertEquals(OrgRegistrationService.ENDPOINT, req.getEndpoint());
            System.assertEquals('POST', req.getMethod());
            System.assertEquals(UserInfo.getOrganizationId(), req.getHeader('Salesforce-Org-Id'));
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            System.assertEquals('test-api-key', body.get('api_key'));
            System.assertEquals(UserInfo.getOrganizationId(), body.get('org_id'));
            System.assertEquals(URL.getOrgDomainUrl().getHost(), body.get('my_domain'));
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody('{"registered":true}');
            return res;
        }
    }

    @IsTest
    static void testRegistersOrg() {
        SettingsService.setApiKey('test-api-key');
        RegisterMock mock = new RegisterMock(201);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        System.enqueueJob(new OrgRegistrationService());
        Test.stopTest();

        System.assertEquals(1, mock.calls);
    }

    @IsTest
    static void testErrorStatusIsHandled() {
        SettingsService.setApiKey('test-api-key');
        RegisterMock mock = new RegisterMock(500);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        System.enqueueJob(new OrgRegistrationService());
        Test.stopTest();

        System.assertEquals(1, mock.calls);
    }

    @IsTest
    static void testSkipsWithoutApiKey() {
        RegisterMock mock = new RegisterMock(201);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        System.enqueueJob(new OrgRegistrationService());
        Test.stopTest();

        System.assertEquals(0, mock.calls, 'No callout without a configured key');
    }

    @IsTest
    static void testEventEnqueuesRegistration() {
        Test.startTest();
        EventBus.publish(new OrgRegistrationEvent__e(RequestedBy__c = UserInfo.getUserId()));
        Test.getEventBus().deliver();
        System.assertEquals(1, [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = 'OrgRegistrationService' AND JobType = 'Queueable'
        ]);
        Test.stopTest();
    }
}
