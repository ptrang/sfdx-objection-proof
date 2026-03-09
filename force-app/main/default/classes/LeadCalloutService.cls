// without sharing: this Queueable runs as the Automated Process User (system context).
// Sharing rules are not applicable; the class only reads Leads that were explicitly
// queued by the platform event, identified by their Id set.
public without sharing class LeadCalloutService implements Queueable, Database.AllowsCallouts {

    private final Set<Id> leadIds;

    public LeadCalloutService(Set<Id> leadIds) {
        this.leadIds = leadIds;
    }

    public void execute(QueueableContext context) {
        Id triggeringUserId = UserInfo.getUserId();
        List<Log__c> logsToCreate = new List<Log__c>();
        String logContext = 'LeadCalloutService.execute';

        logsToCreate.add(new Log__c(
            objectionproof__Level__c = 'INFO',
            objectionproof__Message__c = 'Starting lead callout for ' + leadIds.size() + ' lead(s).',
            objectionproof__Context__c = logContext,
            objectionproof__Triggering_User__c = triggeringUserId
        ));

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

        // WITH SYSTEM_MODE: this Queueable runs as the Automated Process User.
        // FLS enforcement is not applicable in this system-level context.
        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Name, Email, Phone, MobilePhone,
                   Street, City, State, PostalCode
            FROM Lead WHERE Id IN :leadIds
            WITH SYSTEM_MODE
        ];

        if (leads.size() != leadIds.size()) {
            Set<Id> foundIds = (new Map<Id, SObject>(leads)).keySet();
            Set<Id> missingIds = new Set<Id>(leadIds);
            missingIds.removeAll(foundIds);
            logsToCreate.add(new Log__c(
                objectionproof__Level__c = 'WARN',
                objectionproof__Message__c = 'Missing Leads (likely deleted after queuing): ' + String.valueOf(new List<Id>(missingIds)),
                objectionproof__Context__c = logContext,
                objectionproof__Triggering_User__c = triggeringUserId
            ));
        }

        try {
            for (Lead lead : leads) {
                if (String.isBlank(lead.Phone) && String.isBlank(lead.MobilePhone)) {
                    logsToCreate.add(new Log__c(
                        objectionproof__Level__c = 'WARN',
                        objectionproof__Message__c = 'Skipping Lead due to missing phone number. Lead Id: ' + lead.Id,
                        objectionproof__Context__c = logContext,
                        objectionproof__Triggering_User__c = triggeringUserId
                    ));
                    continue;
                }

                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:objectionproof__objproof_lead_namedcred/api/call-lead');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json;charset=UTF-8');

                String phone = String.isNotBlank(lead.Phone) ? lead.Phone : lead.MobilePhone;
                // Strip non-digit characters for the 10-digit phone format
                String cleanPhone = phone.replaceAll('[^0-9]', '');

                Map<String, String> bodyMap = new Map<String, String>{
                    'api_key' => apiKey,
                    'lead_phone' => cleanPhone,
                    'full_name' => lead.Name,
                    'prospect_email' => lead.Email,
                    'street_address' => lead.Street,
                    'city' => lead.City,
                    'state' => lead.State,
                    'zip' => lead.PostalCode
                };

                // Build full_address from components
                List<String> addressParts = new List<String>();
                if (String.isNotBlank(lead.Street)) { addressParts.add(lead.Street); }
                if (String.isNotBlank(lead.City)) { addressParts.add(lead.City); }
                if (String.isNotBlank(lead.State)) { addressParts.add(lead.State); }
                if (String.isNotBlank(lead.PostalCode)) { addressParts.add(lead.PostalCode); }
                if (!addressParts.isEmpty()) {
                    bodyMap.put('full_address', String.join(addressParts, ', '));
                }

                String requestBody = JSON.serialize(bodyMap);
                req.setBody(requestBody);

                logsToCreate.add(new Log__c(
                    objectionproof__Level__c = 'DEBUG',
                    objectionproof__Message__c = 'Sending request for Lead Id: ' + lead.Id,
                    objectionproof__Context__c = logContext,
                    objectionproof__Triggering_User__c = triggeringUserId
                ));

                Http http = new Http();
                try {
                    HttpResponse res = http.send(req);
                    Integer statusCode = res.getStatusCode();
                    if (statusCode < 200 || statusCode >= 300) {
                        logsToCreate.add(new Log__c(
                            objectionproof__Level__c = 'ERROR',
                            objectionproof__Message__c = 'API returned ' + statusCode + ' for Lead Id: ' + lead.Id + '. Response: ' + res.getBody(),
                            objectionproof__Context__c = logContext,
                            objectionproof__Triggering_User__c = triggeringUserId
                        ));
                    }
                } catch (Exception e) {
                    String errorMessage = 'Outbound callout failed for Lead Id: ' + lead.Id + '. Error: ' + e.getMessage() + '\n' + e.getStackTraceString();
                    logsToCreate.add(new Log__c(
                        objectionproof__Level__c = 'ERROR',
                        objectionproof__Message__c = errorMessage,
                        objectionproof__Context__c = logContext,
                        objectionproof__Triggering_User__c = triggeringUserId
                    ));
                }
            }
        } catch (Exception e) {
            String errorMessage = 'Failed in the lead array for loop. Error: ' + e.getMessage() + '\n' + e.getStackTraceString();
            logsToCreate.add(new Log__c(
                objectionproof__Level__c = 'ERROR',
                objectionproof__Message__c = errorMessage,
                objectionproof__Context__c = logContext,
                objectionproof__Triggering_User__c = triggeringUserId
            ));
        }

        logsToCreate.add(new Log__c(
            objectionproof__Level__c = 'INFO',
            objectionproof__Message__c = 'Lead callout process finished.',
            objectionproof__Context__c = logContext,
            objectionproof__Triggering_User__c = triggeringUserId
        ));

        LoggerService.log(logsToCreate);
    }
}
