@IsTest
private class CallActivityServiceTest {

    private static final String TEST_SECRET = 'test-webhook-secret-abc123';

    @TestSetup
    static void makeData() {
        Lead l = new Lead(
            FirstName = 'Patrick',
            LastName = 'TestLead',
            Company = 'Test Co',
            Phone = '2345678901'
        );
        insert l;

        Account a = new Account(Name = 'Test Account');
        insert a;

        Contact c = new Contact(
            FirstName = 'Jane',
            LastName = 'TestContact',
            AccountId = a.Id,
            Phone = '9876543210'
        );
        insert c;

        Opportunity o = new Opportunity(
            Name = 'Test Opp',
            AccountId = a.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert o;

        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = o.Id,
            ContactId = c.Id,
            Role = 'Decision Maker'
        );
        insert ocr;
    }

    private static RestRequest buildRequest(String body) {
        SettingsService.settingsMap.put('Webhook_Secret', new objectionproof__Application_Setting__mdt(
            DeveloperName = 'Webhook_Secret',
            objectionproof__Value__c = TEST_SECRET
        ));
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/v1/call-activity';
        req.httpMethod = 'POST';
        req.headers.put('Authorization', 'Bearer ' + TEST_SECRET);
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        return req;
    }

    @IsTest
    static void testMatchLeadByPhone() {
        Lead existingLead = [SELECT Id FROM Lead WHERE Phone = '2345678901' LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ existingLead.Id });

        RestRequest req = buildRequest('{' +
            '"prospect": "Patrick",' +
            '"summary": "Patrick called about selling his house.",' +
            '"transcript": "AI: Hello. User: Hi.",' +
            '"prospect_phone": "2345678901",' +
            '"details": "Address: 123 Main St",' +
            '"call_url": "https://example.com/recording.wav",' +
            '"subject": "AI Call from Patrick",' +
            '"outcome": "quality_conversation",' +
            '"appointment": "11-04-25 06:00 PM",' +
            '"timezone": "America/New_York"' +
        '}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(201, res.statusCode, 'Should return 201 Created.');

        Lead l = [SELECT Id, op_ai_call_status__c, op_ai_call_notes__c, op_ai_call_outcome__c, op_ai_call_appointment__c
                  FROM Lead WHERE Phone = '2345678901' LIMIT 1];
        System.assertEquals('complete', l.op_ai_call_status__c);
        System.assertEquals('quality_conversation', l.op_ai_call_outcome__c);
        System.assertEquals('11-04-25 06:00 PM', l.op_ai_call_appointment__c);
        System.assert(l.op_ai_call_notes__c.contains('Patrick'), 'Notes should contain prospect name.');
        System.assert(l.op_ai_call_notes__c.contains('quality_conversation'), 'Notes should contain outcome.');
        System.assert(l.op_ai_call_notes__c.contains('123 Main St'), 'Notes should contain details.');

        List<Task> tasks = [SELECT Id, WhoId, Subject, Description, op_recording_url__c FROM Task WHERE WhoId = :l.Id];
        System.assertEquals(1, tasks.size(), 'One Task should be linked to the Lead.');
        System.assertEquals('AI Call from Patrick', tasks[0].Subject);
        System.assertNotEquals(null, tasks[0].op_recording_url__c);

        List<op_Call_Analysis__c> analyses = [
            SELECT op_full_transcript__c, op_full_evaluation__c, op_summary__c, op_outcome__c,
                   op_appointment__c, op_prospect_phone__c, op_prospect_name__c
            FROM op_Call_Analysis__c WHERE op_Task__c = :tasks[0].Id
        ];
        System.assertEquals(1, analyses.size(), 'One Call Analysis record should exist.');
        System.assert(analyses[0].op_full_transcript__c.contains('Hello'), 'Transcript should be populated.');
        System.assertEquals('quality_conversation', analyses[0].op_outcome__c);
        System.assertEquals('11-04-25 06:00 PM', analyses[0].op_appointment__c);
        System.assertEquals('2345678901', analyses[0].op_prospect_phone__c);
        System.assertEquals('Patrick', analyses[0].op_prospect_name__c);
    }

    @IsTest
    static void testMatchContactByPhone() {
        Contact existingContact = [SELECT Id FROM Contact WHERE Phone = '9876543210' LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ existingContact.Id });

        RestRequest req = buildRequest('{' +
            '"prospect": "Jane",' +
            '"summary": "Jane called about the opportunity.",' +
            '"transcript": "AI: Hi Jane.",' +
            '"prospect_phone": "9876543210",' +
            '"details": "Discussed pricing.",' +
            '"subject": "AI Call from Jane",' +
            '"outcome": "follow_up",' +
            '"appointment": "11-05-25 02:00 PM"' +
        '}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(201, res.statusCode);

        Contact c = [SELECT Id FROM Contact WHERE Phone = '9876543210' LIMIT 1];
        Opportunity o = [SELECT Id, op_ai_call_status__c, op_ai_call_outcome__c, op_ai_call_appointment__c, op_ai_call_notes__c
                         FROM Opportunity WHERE Name = 'Test Opp' LIMIT 1];
        List<Task> tasks = [SELECT WhoId, WhatId FROM Task WHERE WhoId = :c.Id];
        System.assertEquals(1, tasks.size());
        System.assertEquals(o.Id, tasks[0].WhatId, 'Task WhatId should be the related Opportunity.');

        System.assertEquals('complete', o.op_ai_call_status__c);
        System.assertEquals('follow_up', o.op_ai_call_outcome__c);
        System.assertEquals('11-05-25 02:00 PM', o.op_ai_call_appointment__c);
        System.assert(o.op_ai_call_notes__c.contains('Jane'), 'Opp notes should contain prospect name.');
    }

    @IsTest
    static void testMatchByProspectNotes() {
        Lead l = [SELECT Id FROM Lead WHERE Phone = '2345678901' LIMIT 1];

        RestRequest req = buildRequest('{' +
            '"prospect": "Patrick",' +
            '"summary": "Direct ID lookup.",' +
            '"transcript": "AI: Hi.",' +
            '"prospect_notes": "' + l.Id + '",' +
            '"subject": "AI Call via CRM ID",' +
            '"outcome": "quality_conversation"' +
        '}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(201, res.statusCode);
        List<Task> tasks = [SELECT WhoId FROM Task WHERE WhoId = :l.Id AND Subject = 'AI Call via CRM ID'];
        System.assertEquals(1, tasks.size());

        Lead updatedLead = [SELECT op_ai_call_status__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('complete', updatedLead.op_ai_call_status__c);
    }

    @IsTest
    static void testMissingAuthHeader() {
        SettingsService.settingsMap.put('Webhook_Secret', new objectionproof__Application_Setting__mdt(
            DeveloperName = 'Webhook_Secret',
            objectionproof__Value__c = TEST_SECRET
        ));
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/v1/call-activity';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"prospect_phone": "1234567890"}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Missing auth header should return 401.');
    }

    @IsTest
    static void testInvalidAuthToken() {
        SettingsService.settingsMap.put('Webhook_Secret', new objectionproof__Application_Setting__mdt(
            DeveloperName = 'Webhook_Secret',
            objectionproof__Value__c = TEST_SECRET
        ));
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/v1/call-activity';
        req.httpMethod = 'POST';
        req.headers.put('Authorization', 'Bearer wrong-secret');
        req.requestBody = Blob.valueOf('{"prospect_phone": "1234567890"}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Wrong token should return 401.');
    }

    @IsTest
    static void testWebhookSecretNotConfigured() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/v1/call-activity';
        req.httpMethod = 'POST';
        req.headers.put('Authorization', 'Bearer something');
        req.requestBody = Blob.valueOf('{"prospect_phone": "1234567890"}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(503, res.statusCode, 'Should return 503 when secret is not configured.');
    }

    @IsTest
    static void testMissingPhoneAndNotes() {
        RestRequest req = buildRequest('{"prospect": "Nobody", "summary": "No phone"}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @IsTest
    static void testEmptyBody() {
        RestRequest req = buildRequest('');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @IsTest
    static void testConvertedLeadByProspectNotes() {
        // Create and convert a Lead
        Lead l = new Lead(
            FirstName = 'Converted',
            LastName = 'TestLead',
            Company = 'Converted Co',
            Phone = '5551112222'
        );
        insert l;

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.Id);
        lc.setConvertedStatus([SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel);
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        System.assert(lcr.isSuccess(), 'Lead conversion should succeed.');

        // Send the old (converted) Lead ID in prospect_notes
        RestRequest req = buildRequest('{' +
            '"prospect": "Converted",' +
            '"summary": "Calling a converted lead.",' +
            '"transcript": "AI: Hi.",' +
            '"prospect_notes": "' + l.Id + '",' +
            '"subject": "AI Call Converted Lead",' +
            '"outcome": "quality_conversation",' +
            '"appointment": "11-10-25 03:00 PM"' +
        '}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(201, res.statusCode);

        // Task should be linked to the converted Contact, not the Lead
        Id convertedContactId = lcr.getContactId();
        List<Task> tasks = [SELECT WhoId, WhatId FROM Task WHERE Subject = 'AI Call Converted Lead'];
        System.assertEquals(1, tasks.size());
        System.assertEquals(convertedContactId, tasks[0].WhoId, 'WhoId should be the converted Contact.');

        // Opportunity should be updated
        Id convertedOppId = lcr.getOpportunityId();
        if (convertedOppId != null) {
            Opportunity o = [SELECT op_ai_call_status__c FROM Opportunity WHERE Id = :convertedOppId];
            System.assertEquals('complete', o.op_ai_call_status__c);
        }
    }

    @IsTest
    static void testNoMatchCreatesNewLead() {
        RestRequest req = buildRequest('{' +
            '"prospect": "BrandNew",' +
            '"summary": "No matching record.",' +
            '"transcript": "AI: Hi.",' +
            '"prospect_phone": "0000000000",' +
            '"subject": "AI Call from BrandNew",' +
            '"outcome": "no_answer",' +
            '"appointment": "11-15-25 10:00 AM"' +
        '}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(201, res.statusCode, 'Should return 201 Created.');

        // Verify a new Lead was created
        List<Lead> newLeads = [SELECT Id, LastName, Phone, Company, LeadSource,
                                      op_ai_call_status__c, op_ai_call_outcome__c, op_ai_call_appointment__c, op_ai_call_notes__c
                               FROM Lead WHERE LastName = 'BrandNew'];
        System.assertEquals(1, newLeads.size(), 'A new Lead should be created.');
        System.assertEquals('0000000000', newLeads[0].Phone);
        System.assertEquals('AI Call Lead', newLeads[0].Company);
        System.assertEquals('AI Call', newLeads[0].LeadSource);
        System.assertEquals('complete', newLeads[0].op_ai_call_status__c);
        System.assertEquals('no_answer', newLeads[0].op_ai_call_outcome__c);
        System.assertEquals('11-15-25 10:00 AM', newLeads[0].op_ai_call_appointment__c);
        System.assert(newLeads[0].op_ai_call_notes__c.contains('BrandNew'), 'Notes should contain prospect name.');

        // Verify the Task is linked to the new Lead
        List<Task> tasks = [SELECT WhoId FROM Task WHERE Subject = 'AI Call from BrandNew'];
        System.assertEquals(1, tasks.size());
        System.assertEquals(newLeads[0].Id, tasks[0].WhoId, 'Task should be linked to the new Lead.');
    }
}
