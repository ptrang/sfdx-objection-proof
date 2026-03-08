@RestResource(urlMapping='/v1/call-activity/*')
// without sharing: guest user context — SYSTEM_MODE handles CRUD bypass for inserts.
global without sharing class CallActivityService {

    private class CallPayload {
        public String prospect { get; set; }
        public String summary { get; set; }
        public String transcript { get; set; }
        public String prospect_phone { get; set; }
        public String details { get; set; }
        public String call_url { get; set; }
        public String appointment { get; set; }
        public String email_subject { get; set; }
        public String outcome { get; set; }
        public String prospect_notes { get; set; }
        public String subject { get; set; }
        public String timezone { get; set; }
    }

    @HttpPost
    global static void createCallActivity() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;

        // Validate Bearer token against the stored webhook secret.
        String expectedToken = SettingsService.getString('Webhook_Secret', '');
        if (String.isBlank(expectedToken)) {
            response.statusCode = 503;
            response.responseBody = Blob.valueOf('{"error":"Webhook secret is not configured."}');
            return;
        }

        String authHeader = request.headers.get('Authorization');
        if (String.isBlank(authHeader) || !authHeader.startsWith('Bearer ')) {
            response.statusCode = 401;
            response.responseBody = Blob.valueOf('{"error":"Missing or invalid Authorization header."}');
            return;
        }

        String providedToken = authHeader.substring(7).trim();
        // Constant-time comparison to prevent timing attacks.
        Blob expected = Blob.valueOf(expectedToken);
        Blob provided = Blob.valueOf(providedToken);
        if (!EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', expected))
              .equals(EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', provided)))) {
            response.statusCode = 401;
            response.responseBody = Blob.valueOf('{"error":"Invalid authorization token."}');
            return;
        }

        if (request.requestBody == null || request.requestBody.size() == 0) {
            response.statusCode = 400;
            response.responseBody = Blob.valueOf('{"error":"Request body is required."}');
            return;
        }

        try {
            CallPayload payload = (CallPayload) JSON.deserialize(
                request.requestBody.toString(),
                CallPayload.class
            );

            if (String.isBlank(payload.prospect_phone) && String.isBlank(payload.prospect_notes)) {
                response.statusCode = 400;
                response.responseBody = Blob.valueOf('{"error":"prospect_phone or prospect_notes is required."}');
                return;
            }

            Id whoId;
            Id whatId;

            // 1. Try prospect_notes as a Salesforce record ID
            if (String.isNotBlank(payload.prospect_notes)) {
                try {
                    Id recordId = Id.valueOf(payload.prospect_notes);
                    String sObjectType = recordId.getSObjectType().getDescribe().getName();
                    if (sObjectType == 'Lead') {
                        whoId = recordId;
                    } else if (sObjectType == 'Contact') {
                        whoId = recordId;
                        whatId = findOpportunityForContact(recordId);
                    } else if (sObjectType == 'Opportunity') {
                        whatId = recordId;
                    }
                } catch (Exception e) {
                    // Not a valid Salesforce ID — fall through to phone lookup.
                }
            }

            // 2. Fall back to SOSL phone search
            if (whoId == null && whatId == null && String.isNotBlank(payload.prospect_phone)) {
                String phone = payload.prospect_phone.replaceAll('[^0-9]', '');
                if (phone.length() >= 7) {
                    List<List<SObject>> results = [
                        FIND :phone IN PHONE FIELDS
                        RETURNING Lead(Id WHERE IsConverted = false LIMIT 1),
                                   Contact(Id LIMIT 1)
                    ];
                    List<Lead> leads = (List<Lead>) results[0];
                    List<Contact> contacts = (List<Contact>) results[1];

                    if (!leads.isEmpty()) {
                        whoId = leads[0].Id;
                    } else if (!contacts.isEmpty()) {
                        whoId = contacts[0].Id;
                        whatId = findOpportunityForContact(contacts[0].Id);
                    }
                }
            }

            // 3. Create the Task (call activity)
            Task t = new Task(
                Subject = String.isNotBlank(payload.subject) ? payload.subject : 'AI Call from ' + payload.prospect,
                Description = payload.summary,
                Status = 'Completed',
                Priority = 'Normal',
                TaskSubtype = 'Call',
                op_recording_url__c = payload.call_url,
                ActivityDate = Date.today()
            );
            if (whoId != null) { t.WhoId = whoId; }
            if (whatId != null) { t.WhatId = whatId; }

            Database.insert(t, AccessLevel.SYSTEM_MODE);

            // 4. Create Call Analysis child record
            op_Call_Analysis__c analysis = new op_Call_Analysis__c(
                op_Task__c = t.Id,
                op_full_transcript__c = payload.transcript,
                op_full_evaluation__c = payload.details,
                op_evaluation_url__c = payload.call_url
            );
            Database.insert(analysis, AccessLevel.SYSTEM_MODE);

            response.statusCode = 201;
            response.responseBody = Blob.valueOf('{"taskId":"' + t.Id + '"}');

        } catch (Exception e) {
            response.statusCode = 400;
            response.responseBody = Blob.valueOf('{"error":"Invalid request body."}');
        }
    }

    private static Id findOpportunityForContact(Id contactId) {
        List<OpportunityContactRole> ocrs = [
            SELECT OpportunityId FROM OpportunityContactRole
            WHERE ContactId = :contactId
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        return ocrs.isEmpty() ? null : ocrs[0].OpportunityId;
    }
}
