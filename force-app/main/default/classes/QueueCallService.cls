// without sharing: this Queueable runs as the Automated Process User (system context).
public without sharing class QueueCallService implements Queueable, Database.AllowsCallouts {

    public class QueueCallRequest {
        public Id recordId;
        public String objectType;

        public QueueCallRequest(Id recordId, String objectType) {
            this.recordId = recordId;
            this.objectType = objectType;
        }
    }

    private static final String ENDPOINT = 'callout:objectionproof__objproof_lead_namedcred/api/queue-call';
    private final List<QueueCallRequest> requests;

    public QueueCallService(List<QueueCallRequest> requests) {
        this.requests = requests;
    }

    public void execute(QueueableContext context) {
        String logContext = 'QueueCallService.execute';
        List<Log__c> logsToCreate = new List<Log__c>();
        Id triggeringUserId = UserInfo.getUserId();

        String apiKey = SettingsService.getString('Lead_Api_Key', '');
        if (String.isBlank(apiKey) || apiKey == 'CONFIGURE_POST_INSTALL') {
            logsToCreate.add(new Log__c(
                objectionproof__Level__c = 'ERROR',
                objectionproof__Message__c = 'Lead_Api_Key is not configured. Set it in Custom Metadata: Objection Proof Setting > Lead Api Key.',
                objectionproof__Context__c = logContext,
                objectionproof__Triggering_User__c = triggeringUserId
            ));
            LoggerService.log(logsToCreate);
            return;
        }

        // Separate Lead and Opportunity requests
        Set<Id> leadIds = new Set<Id>();
        Set<Id> oppIds = new Set<Id>();

        for (QueueCallRequest req : requests) {
            if (req.objectType == 'Lead') {
                leadIds.add(req.recordId);
            } else if (req.objectType == 'Opportunity') {
                oppIds.add(req.recordId);
            }
        }

        // Determine call_type per record based on existing call activity.
        // "old_lead_fu" if any Call tasks exist, otherwise "never_reached_fu".
        Map<Id, String> callTypeByRecordId = new Map<Id, String>();
        Set<Id> allIds = new Set<Id>();
        allIds.addAll(leadIds);
        allIds.addAll(oppIds);
        // Default all to never_reached_fu
        for (Id rid : allIds) {
            callTypeByRecordId.put(rid, 'never_reached_fu');
        }
        // Find records that have existing call Tasks (WhoId for Leads, WhatId for Opportunities)
        for (Task t : [
            SELECT WhoId, WhatId FROM Task
            WHERE (WhoId IN :leadIds OR WhatId IN :oppIds)
            AND TaskSubtype = 'Call'
            WITH SYSTEM_MODE
            LIMIT 2000
        ]) {
            if (t.WhoId != null && leadIds.contains(t.WhoId)) {
                callTypeByRecordId.put(t.WhoId, 'old_lead_fu');
            }
            if (t.WhatId != null && oppIds.contains(t.WhatId)) {
                callTypeByRecordId.put(t.WhatId, 'old_lead_fu');
            }
        }

        // Build payload items: one per record
        Map<Id, Map<String, String>> payloadsByRecordId = new Map<Id, Map<String, String>>();

        if (!leadIds.isEmpty()) {
            List<Lead> leads = [
                SELECT Id, Name, Email, Phone, MobilePhone, Street, City, State, PostalCode
                FROM Lead WHERE Id IN :leadIds WITH SYSTEM_MODE
            ];
            for (Lead l : leads) {
                String phone = String.isNotBlank(l.Phone) ? l.Phone : l.MobilePhone;
                if (String.isBlank(phone)) {
                    logsToCreate.add(new Log__c(
                        objectionproof__Level__c = 'WARN',
                        objectionproof__Message__c = 'Skipping Lead with no phone: ' + l.Id,
                        objectionproof__Context__c = logContext,
                        objectionproof__Triggering_User__c = triggeringUserId
                    ));
                    // Mark as failed since we can't queue without a phone
                    updateStatus(l.Id, 'Lead', 'failed');
                    continue;
                }
                Map<String, String> body = new Map<String, String>{
                    'api_key' => apiKey,
                    'lead_phone' => phone.replaceAll('[^0-9]', ''),
                    'call_type' => callTypeByRecordId.get(l.Id)
                };
                if (String.isNotBlank(l.Name)) { body.put('full_name', l.Name); }
                if (String.isNotBlank(l.Email)) { body.put('prospect_email', l.Email); }
                if (String.isNotBlank(l.Street)) { body.put('street_address', l.Street); }
                if (String.isNotBlank(l.City)) { body.put('city', l.City); }
                if (String.isNotBlank(l.State)) { body.put('state', l.State); }
                if (String.isNotBlank(l.PostalCode)) { body.put('zip', l.PostalCode); }

                List<String> addrParts = new List<String>();
                if (String.isNotBlank(l.Street)) { addrParts.add(l.Street); }
                if (String.isNotBlank(l.City)) { addrParts.add(l.City); }
                if (String.isNotBlank(l.State)) { addrParts.add(l.State); }
                if (String.isNotBlank(l.PostalCode)) { addrParts.add(l.PostalCode); }
                if (!addrParts.isEmpty()) { body.put('full_address', String.join(addrParts, ', ')); }

                payloadsByRecordId.put(l.Id, body);
            }
        }

        if (!oppIds.isEmpty()) {
            // Find the primary Contact for each Opportunity to get phone/email/address
            Map<Id, Contact> contactByOppId = new Map<Id, Contact>();
            List<OpportunityContactRole> ocrs = [
                SELECT OpportunityId, Contact.Name, Contact.Email, Contact.Phone, Contact.MobilePhone,
                       Contact.MailingStreet, Contact.MailingCity, Contact.MailingState, Contact.MailingPostalCode
                FROM OpportunityContactRole
                WHERE OpportunityId IN :oppIds AND IsPrimary = true
                WITH SYSTEM_MODE
            ];
            for (OpportunityContactRole ocr : ocrs) {
                contactByOppId.put(ocr.OpportunityId, ocr.Contact);
            }
            // Fall back to any contact role if no primary
            if (contactByOppId.size() < oppIds.size()) {
                List<OpportunityContactRole> fallbackOcrs = [
                    SELECT OpportunityId, Contact.Name, Contact.Email, Contact.Phone, Contact.MobilePhone,
                           Contact.MailingStreet, Contact.MailingCity, Contact.MailingState, Contact.MailingPostalCode
                    FROM OpportunityContactRole
                    WHERE OpportunityId IN :oppIds AND OpportunityId NOT IN :contactByOppId.keySet()
                    WITH SYSTEM_MODE
                    ORDER BY CreatedDate DESC
                ];
                for (OpportunityContactRole ocr : fallbackOcrs) {
                    if (!contactByOppId.containsKey(ocr.OpportunityId)) {
                        contactByOppId.put(ocr.OpportunityId, ocr.Contact);
                    }
                }
            }

            for (Id oppId : oppIds) {
                Contact c = contactByOppId.get(oppId);
                if (c == null) {
                    logsToCreate.add(new Log__c(
                        objectionproof__Level__c = 'WARN',
                        objectionproof__Message__c = 'Skipping Opportunity with no related Contact: ' + oppId,
                        objectionproof__Context__c = logContext,
                        objectionproof__Triggering_User__c = triggeringUserId
                    ));
                    updateStatus(oppId, 'Opportunity', 'failed');
                    continue;
                }

                String phone = String.isNotBlank(c.Phone) ? c.Phone : c.MobilePhone;
                if (String.isBlank(phone)) {
                    logsToCreate.add(new Log__c(
                        objectionproof__Level__c = 'WARN',
                        objectionproof__Message__c = 'Skipping Opportunity — related Contact has no phone: ' + oppId,
                        objectionproof__Context__c = logContext,
                        objectionproof__Triggering_User__c = triggeringUserId
                    ));
                    updateStatus(oppId, 'Opportunity', 'failed');
                    continue;
                }

                Map<String, String> body = new Map<String, String>{
                    'api_key' => apiKey,
                    'lead_phone' => phone.replaceAll('[^0-9]', ''),
                    'call_type' => callTypeByRecordId.get(oppId)
                };
                if (String.isNotBlank(c.Name)) { body.put('full_name', c.Name); }
                if (String.isNotBlank(c.Email)) { body.put('prospect_email', c.Email); }
                if (String.isNotBlank(c.MailingStreet)) { body.put('street_address', c.MailingStreet); }
                if (String.isNotBlank(c.MailingCity)) { body.put('city', c.MailingCity); }
                if (String.isNotBlank(c.MailingState)) { body.put('state', c.MailingState); }
                if (String.isNotBlank(c.MailingPostalCode)) { body.put('zip', c.MailingPostalCode); }

                List<String> addrParts = new List<String>();
                if (String.isNotBlank(c.MailingStreet)) { addrParts.add(c.MailingStreet); }
                if (String.isNotBlank(c.MailingCity)) { addrParts.add(c.MailingCity); }
                if (String.isNotBlank(c.MailingState)) { addrParts.add(c.MailingState); }
                if (String.isNotBlank(c.MailingPostalCode)) { addrParts.add(c.MailingPostalCode); }
                if (!addrParts.isEmpty()) { body.put('full_address', String.join(addrParts, ', ')); }

                payloadsByRecordId.put(oppId, body);
            }
        }

        // Make individual callouts per record
        for (Id recordId : payloadsByRecordId.keySet()) {
            String objectType = leadIds.contains(recordId) ? 'Lead' : 'Opportunity';
            Map<String, String> body = payloadsByRecordId.get(recordId);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json;charset=UTF-8');
            req.setBody(JSON.serialize(body));

            try {
                Http http = new Http();
                HttpResponse res = http.send(req);
                Integer statusCode = res.getStatusCode();

                if (statusCode >= 200 && statusCode < 300) {
                    logsToCreate.add(new Log__c(
                        objectionproof__Level__c = 'INFO',
                        objectionproof__Message__c = 'Successfully queued call for ' + objectType + ' Id: ' + recordId,
                        objectionproof__Context__c = logContext,
                        objectionproof__Triggering_User__c = triggeringUserId
                    ));
                    updateStatus(recordId, objectType, 'queued');
                } else if (statusCode == 409) {
                    logsToCreate.add(new Log__c(
                        objectionproof__Level__c = 'WARN',
                        objectionproof__Message__c = 'Already queued for ' + objectType + ' Id: ' + recordId,
                        objectionproof__Context__c = logContext,
                        objectionproof__Triggering_User__c = triggeringUserId
                    ));
                    updateStatus(recordId, objectType, 'queued');
                } else {
                    logsToCreate.add(new Log__c(
                        objectionproof__Level__c = 'ERROR',
                        objectionproof__Message__c = 'API returned ' + statusCode + ' for ' + objectType + ' Id: ' + recordId + '. Response: ' + res.getBody(),
                        objectionproof__Context__c = logContext,
                        objectionproof__Triggering_User__c = triggeringUserId
                    ));
                    updateStatus(recordId, objectType, 'failed');
                }
            } catch (Exception e) {
                logsToCreate.add(new Log__c(
                    objectionproof__Level__c = 'ERROR',
                    objectionproof__Message__c = 'Callout failed for ' + objectType + ' Id: ' + recordId + '. Error: ' + e.getMessage(),
                    objectionproof__Context__c = logContext,
                    objectionproof__Triggering_User__c = triggeringUserId
                ));
                updateStatus(recordId, objectType, 'failed');
            }
        }

        LoggerService.log(logsToCreate);
    }

    private static void updateStatus(Id recordId, String objectType, String status) {
        if (objectType == 'Lead') {
            Database.update(new Lead(Id = recordId, op_ai_call_status__c = status), AccessLevel.SYSTEM_MODE);
        } else if (objectType == 'Opportunity') {
            Database.update(new Opportunity(Id = recordId, op_ai_call_status__c = status), AccessLevel.SYSTEM_MODE);
        }
    }
}
