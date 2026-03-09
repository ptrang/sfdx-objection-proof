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
            String matchedType; // 'Lead', 'Contact', or 'Opportunity'

            // 1. Try prospect_notes as a Salesforce record ID
            if (String.isNotBlank(payload.prospect_notes)) {
                try {
                    Id recordId = Id.valueOf(payload.prospect_notes);
                    String sObjectType = recordId.getSObjectType().getDescribe().getName();
                    if (sObjectType == 'Lead') {
                        // Check if the Lead has been converted
                        List<Lead> leadCheck = [
                            SELECT Id, IsConverted, ConvertedContactId, ConvertedOpportunityId
                            FROM Lead WHERE Id = :recordId LIMIT 1
                        ];
                        if (!leadCheck.isEmpty() && leadCheck[0].IsConverted) {
                            // Follow the conversion chain
                            if (leadCheck[0].ConvertedContactId != null) {
                                whoId = leadCheck[0].ConvertedContactId;
                                matchedType = 'Contact';
                            }
                            if (leadCheck[0].ConvertedOpportunityId != null) {
                                whatId = leadCheck[0].ConvertedOpportunityId;
                            } else if (whoId != null) {
                                whatId = findOpportunityForContact(whoId);
                            }
                        } else {
                            whoId = recordId;
                            matchedType = 'Lead';
                        }
                    } else if (sObjectType == 'Contact') {
                        whoId = recordId;
                        matchedType = 'Contact';
                        whatId = findOpportunityForContact(recordId);
                    } else if (sObjectType == 'Opportunity') {
                        whatId = recordId;
                        matchedType = 'Opportunity';
                    }
                } catch (Exception e) {
                    // Not a valid Salesforce ID — fall through to phone lookup.
                }
            }

            // 2. Fall back to SOSL phone search
            if (whoId == null && whatId == null && String.isNotBlank(payload.prospect_phone)) {
                String phone = payload.prospect_phone.replaceAll('[^0-9]', '');
                if (phone.length() >= 7) {
                    // Search both unconverted Leads and Contacts.
                    // Converted Leads are also searched to follow the conversion chain.
                    List<List<SObject>> results = [
                        FIND :phone IN PHONE FIELDS
                        RETURNING Lead(Id, IsConverted, ConvertedContactId, ConvertedOpportunityId LIMIT 1),
                                   Contact(Id LIMIT 1)
                    ];
                    List<Lead> leads = (List<Lead>) results[0];
                    List<Contact> contacts = (List<Contact>) results[1];

                    if (!leads.isEmpty()) {
                        Lead matchedLead = leads[0];
                        if (matchedLead.IsConverted) {
                            // Follow conversion chain to Contact/Opportunity
                            if (matchedLead.ConvertedContactId != null) {
                                whoId = matchedLead.ConvertedContactId;
                                matchedType = 'Contact';
                            }
                            if (matchedLead.ConvertedOpportunityId != null) {
                                whatId = matchedLead.ConvertedOpportunityId;
                            } else if (whoId != null) {
                                whatId = findOpportunityForContact(whoId);
                            }
                        } else {
                            whoId = matchedLead.Id;
                            matchedType = 'Lead';
                        }
                    } else if (!contacts.isEmpty()) {
                        whoId = contacts[0].Id;
                        matchedType = 'Contact';
                        whatId = findOpportunityForContact(contacts[0].Id);
                    }
                }
            }

            // 3. If no match found, create a new Lead
            if (whoId == null && whatId == null) {
                Lead newLead = new Lead(
                    LastName = String.isNotBlank(payload.prospect) ? payload.prospect : 'Unknown',
                    Company = 'AI Call Lead',
                    Phone = payload.prospect_phone,
                    LeadSource = 'AI Call'
                );
                Database.insert(newLead, AccessLevel.SYSTEM_MODE);
                whoId = newLead.Id;
                matchedType = 'Lead';
            }

            // Create the Task (call activity) with full payload data
            String callStatus = 'complete';
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

            // Create Call Analysis child record with all payload data
            op_Call_Analysis__c analysis = new op_Call_Analysis__c(
                op_Task__c = t.Id,
                op_full_transcript__c = payload.transcript,
                op_full_evaluation__c = payload.details,
                op_evaluation_url__c = payload.call_url,
                op_summary__c = payload.summary,
                op_outcome__c = payload.outcome,
                op_appointment__c = payload.appointment,
                op_prospect_phone__c = payload.prospect_phone,
                op_prospect_name__c = payload.prospect
            );
            Database.insert(analysis, AccessLevel.SYSTEM_MODE);

            // Build the combined notes for Lead/Opportunity
            String callNotes = buildCallNotes(payload);

            // Update the matched or newly created Lead, or Opportunity, with AI call fields
            if (matchedType == 'Lead' && whoId != null) {
                Lead l = new Lead(
                    Id = whoId,
                    op_ai_call_status__c = callStatus,
                    op_ai_call_notes__c = callNotes,
                    op_ai_call_outcome__c = payload.outcome,
                    op_ai_call_appointment__c = payload.appointment
                );
                Database.update(l, AccessLevel.SYSTEM_MODE);
            }

            if (whatId != null) {
                Opportunity o = new Opportunity(
                    Id = whatId,
                    op_ai_call_status__c = callStatus,
                    op_ai_call_notes__c = callNotes,
                    op_ai_call_outcome__c = payload.outcome,
                    op_ai_call_appointment__c = payload.appointment
                );
                Database.update(o, AccessLevel.SYSTEM_MODE);
            }

            response.statusCode = 201;
            response.responseBody = Blob.valueOf('{"taskId":"' + t.Id + '"}');

        } catch (Exception e) {
            response.statusCode = 400;
            response.responseBody = Blob.valueOf('{"error":"Invalid request body."}');
        }
    }

    private static String buildCallNotes(CallPayload payload) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(payload.prospect)) {
            parts.add('Prospect: ' + payload.prospect);
        }
        if (String.isNotBlank(payload.outcome)) {
            parts.add('Outcome: ' + payload.outcome);
        }
        if (String.isNotBlank(payload.appointment)) {
            parts.add('Appointment: ' + payload.appointment);
        }
        if (String.isNotBlank(payload.summary)) {
            parts.add('Summary: ' + payload.summary);
        }
        if (String.isNotBlank(payload.details)) {
            parts.add('Details: ' + payload.details);
        }
        return String.join(parts, '\n');
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
