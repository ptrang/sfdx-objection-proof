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
        req.addHeader('Authorization', 'Bearer ' + TEST_SECRET);
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        return req;
    }

    @IsTest
    static void testMatchLeadByPhone() {
        RestRequest req = buildRequest('{' +
            '"prospect": "Patrick",' +
            '"summary": "Patrick called about selling his house.",' +
            '"transcript": "AI: Hello. User: Hi.",' +
            '"prospect_phone": "2345678901",' +
            '"details": "Address: 123 Main St",' +
            '"call_url": "https://example.com/recording.wav",' +
            '"subject": "AI Call from Patrick",' +
            '"outcome": "quality_conversation"' +
        '}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(201, res.statusCode, 'Should return 201 Created.');

        Lead l = [SELECT Id FROM Lead WHERE Phone = '2345678901' LIMIT 1];
        List<Task> tasks = [SELECT Id, WhoId, Subject, Description, op_recording_url__c FROM Task WHERE WhoId = :l.Id];
        System.assertEquals(1, tasks.size(), 'One Task should be linked to the Lead.');
        System.assertEquals('AI Call from Patrick', tasks[0].Subject);
        System.assertNotEquals(null, tasks[0].op_recording_url__c);

        List<op_Call_Analysis__c> analyses = [
            SELECT op_full_transcript__c, op_full_evaluation__c
            FROM op_Call_Analysis__c WHERE op_Task__c = :tasks[0].Id
        ];
        System.assertEquals(1, analyses.size(), 'One Call Analysis record should exist.');
        System.assert(analyses[0].op_full_transcript__c.contains('Hello'), 'Transcript should be populated.');
    }

    @IsTest
    static void testMatchContactByPhone() {
        RestRequest req = buildRequest('{' +
            '"prospect": "Jane",' +
            '"summary": "Jane called about the opportunity.",' +
            '"transcript": "AI: Hi Jane.",' +
            '"prospect_phone": "9876543210",' +
            '"details": "Discussed pricing.",' +
            '"subject": "AI Call from Jane"' +
        '}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(201, res.statusCode);

        Contact c = [SELECT Id FROM Contact WHERE Phone = '9876543210' LIMIT 1];
        Opportunity o = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp' LIMIT 1];
        List<Task> tasks = [SELECT WhoId, WhatId FROM Task WHERE WhoId = :c.Id];
        System.assertEquals(1, tasks.size());
        System.assertEquals(o.Id, tasks[0].WhatId, 'Task WhatId should be the related Opportunity.');
    }

    @IsTest
    static void testMatchByProspectNotes() {
        Lead l = [SELECT Id FROM Lead WHERE Phone = '2345678901' LIMIT 1];

        RestRequest req = buildRequest('{' +
            '"prospect": "Patrick",' +
            '"summary": "Direct ID lookup.",' +
            '"transcript": "AI: Hi.",' +
            '"prospect_notes": "' + l.Id + '",' +
            '"subject": "AI Call via CRM ID"' +
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
        req.addHeader('Authorization', 'Bearer wrong-secret');
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
        // settingsMap is empty — no Webhook_Secret configured.
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/v1/call-activity';
        req.httpMethod = 'POST';
        req.addHeader('Authorization', 'Bearer something');
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
    static void testNoMatchCreatesUnlinkedTask() {
        RestRequest req = buildRequest('{' +
            '"prospect": "Unknown",' +
            '"summary": "No matching record.",' +
            '"transcript": "AI: Hi.",' +
            '"prospect_phone": "0000000000",' +
            '"subject": "AI Call from Unknown"' +
        '}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        CallActivityService.createCallActivity();
        Test.stopTest();

        System.assertEquals(201, res.statusCode, 'Should still create the task even without a match.');
        List<Task> tasks = [SELECT WhoId, WhatId FROM Task WHERE Subject = 'AI Call from Unknown'];
        System.assertEquals(1, tasks.size());
        System.assertEquals(null, tasks[0].WhoId);
        System.assertEquals(null, tasks[0].WhatId);
    }
}
