@IsTest
private class QueueCallServiceTest {

    private class MockQueueCallSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getEndpoint().contains('objproof_lead_namedcred'));

            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            System.assertEquals('test-api-key', (String) body.get('api_key'));
            System.assert(String.isNotBlank((String) body.get('lead_phone')));
            System.assert(String.isNotBlank((String) body.get('call_type')));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"results":[{"success":true,"queue_id":42}]}');
            return res;
        }
    }

    private class MockQueueCallConflict implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(409);
            res.setBody('{"error":"Already queued"}');
            return res;
        }
    }

    private class MockQueueCallError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal server error"}');
            return res;
        }
    }

    private static void injectApiKey() {
        SettingsService.settingsMap = new Map<String, Application_Setting__mdt>{
            'Lead_Api_Key' => new Application_Setting__mdt(
                DeveloperName = 'Lead_Api_Key',
                objectionproof__Value__c = 'test-api-key'
            )
        };
    }

    @IsTest
    static void testQueueCallForLead() {
        injectApiKey();

        Lead l = new Lead(
            FirstName = 'Test', LastName = 'Lead', Company = 'Test Co',
            Phone = '5551234567', Email = 'test@example.com',
            Street = '123 Main St', City = 'Austin', State = 'TX', PostalCode = '78701'
        );
        insert l;

        Test.setMock(HttpCalloutMock.class, new MockQueueCallSuccess());

        List<QueueCallService.QueueCallRequest> requests = new List<QueueCallService.QueueCallRequest>{
            new QueueCallService.QueueCallRequest(l.Id, 'Lead', 'never_reached_fu')
        };

        Test.startTest();
        System.enqueueJob(new QueueCallService(requests));
        Test.stopTest();

        Lead updated = [SELECT op_ai_call_status__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('queued', updated.op_ai_call_status__c);
    }

    @IsTest
    static void testQueueCallForOpportunity() {
        injectApiKey();

        Account a = new Account(Name = 'Test Acct');
        insert a;

        Contact c = new Contact(
            FirstName = 'Jane', LastName = 'Contact', AccountId = a.Id,
            Phone = '5559876543', Email = 'jane@example.com',
            MailingStreet = '456 Oak Ave', MailingCity = 'Denver', MailingState = 'CO', MailingPostalCode = '80202'
        );
        insert c;

        Opportunity o = new Opportunity(
            Name = 'Test Opp', AccountId = a.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert o;

        insert new OpportunityContactRole(OpportunityId = o.Id, ContactId = c.Id, IsPrimary = true);

        Test.setMock(HttpCalloutMock.class, new MockQueueCallSuccess());

        List<QueueCallService.QueueCallRequest> requests = new List<QueueCallService.QueueCallRequest>{
            new QueueCallService.QueueCallRequest(o.Id, 'Opportunity', 'old_lead_fu')
        };

        Test.startTest();
        System.enqueueJob(new QueueCallService(requests));
        Test.stopTest();

        Opportunity updated = [SELECT op_ai_call_status__c FROM Opportunity WHERE Id = :o.Id];
        System.assertEquals('queued', updated.op_ai_call_status__c);
    }

    @IsTest
    static void testConflictStillMarksQueued() {
        injectApiKey();

        Lead l = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Co', Phone = '5551111111');
        insert l;

        Test.setMock(HttpCalloutMock.class, new MockQueueCallConflict());

        List<QueueCallService.QueueCallRequest> requests = new List<QueueCallService.QueueCallRequest>{
            new QueueCallService.QueueCallRequest(l.Id, 'Lead', 'old_lead_fu')
        };

        Test.startTest();
        System.enqueueJob(new QueueCallService(requests));
        Test.stopTest();

        Lead updated = [SELECT op_ai_call_status__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('queued', updated.op_ai_call_status__c);
    }

    @IsTest
    static void testErrorMarksStatusFailed() {
        injectApiKey();

        Lead l = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Co', Phone = '5552222222');
        insert l;

        Test.setMock(HttpCalloutMock.class, new MockQueueCallError());

        List<QueueCallService.QueueCallRequest> requests = new List<QueueCallService.QueueCallRequest>{
            new QueueCallService.QueueCallRequest(l.Id, 'Lead', 'old_lead_fu')
        };

        Test.startTest();
        System.enqueueJob(new QueueCallService(requests));
        Test.stopTest();

        Lead updated = [SELECT op_ai_call_status__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('failed', updated.op_ai_call_status__c);
    }

    @IsTest
    static void testMissingApiKeyAborts() {
        SettingsService.settingsMap = new Map<String, Application_Setting__mdt>();

        Lead l = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Co', Phone = '5553333333');
        insert l;

        List<QueueCallService.QueueCallRequest> requests = new List<QueueCallService.QueueCallRequest>{
            new QueueCallService.QueueCallRequest(l.Id, 'Lead', 'old_lead_fu')
        };

        Test.startTest();
        System.enqueueJob(new QueueCallService(requests));
        Test.stopTest();

        // No callout made, no status update — Lead status should be unchanged
        Lead updated = [SELECT op_ai_call_status__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(null, updated.op_ai_call_status__c);
    }

    @IsTest
    static void testLeadWithNoPhoneMarksFailed() {
        injectApiKey();

        Lead l = new Lead(FirstName = 'Test', LastName = 'NoPhone', Company = 'Test Co');
        insert l;

        Test.setMock(HttpCalloutMock.class, new MockQueueCallSuccess());

        List<QueueCallService.QueueCallRequest> requests = new List<QueueCallService.QueueCallRequest>{
            new QueueCallService.QueueCallRequest(l.Id, 'Lead', 'old_lead_fu')
        };

        Test.startTest();
        System.enqueueJob(new QueueCallService(requests));
        Test.stopTest();

        Lead updated = [SELECT op_ai_call_status__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('failed', updated.op_ai_call_status__c);
    }

    @IsTest
    static void testTriggerPublishesEventOnLeadStatusChange() {
        injectApiKey();

        Lead l = new Lead(FirstName = 'Test', LastName = 'Trigger', Company = 'Test Co', Phone = '5554444444');
        insert l;

        Test.setMock(HttpCalloutMock.class, new MockQueueCallSuccess());

        Test.startTest();
        l.op_ai_call_status__c = 'call';
        l.op_ai_call_type__c = 'never_reached_fu';
        update l;
        Test.getEventBus().deliver();
        Test.stopTest();

        // Verify the async job was enqueued
        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'QueueCallService'];
        System.assert(!jobs.isEmpty(), 'QueueCallService should have been enqueued.');
    }
}
