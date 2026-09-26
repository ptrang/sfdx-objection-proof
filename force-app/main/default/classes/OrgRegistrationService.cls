// Registers this org with Objection Proof so its Salesforce connection appears in
// the customer's Objection Proof settings. Sends only the org ID and My Domain host,
// authenticated by the org's Objection Proof API key.
//
// without sharing: this Queueable runs as the Automated Process User (system
// context) and reads no records.
public without sharing class OrgRegistrationService implements Queueable, Database.AllowsCallouts {

    @TestVisible
    private static final String ENDPOINT = 'callout:objectionproof__objproof_lead_namedcred/api/integrations/salesforce/register';

    public void execute(QueueableContext context) {
        String logContext = 'OrgRegistrationService.execute';
        String apiKey = SettingsService.getApiKey();
        if (String.isBlank(apiKey)) {
            LoggerService.log('WARN', 'Skipped org registration: API key is not configured.', logContext);
            return;
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');
        req.setHeader('Salesforce-Org-Id', UserInfo.getOrganizationId());
        req.setTimeout(20000);
        req.setBody(JSON.serialize(new Map<String, String>{
            'api_key' => apiKey,
            'org_id' => UserInfo.getOrganizationId(),
            'my_domain' => URL.getOrgDomainUrl().getHost()
        }));

        try {
            Integer status = new Http().send(req).getStatusCode();
            if (status == 200 || status == 201) {
                LoggerService.log('INFO', 'Org registered with Objection Proof (HTTP ' + status + ').', logContext);
            } else {
                LoggerService.log('ERROR', 'Org registration returned HTTP ' + status + '.', logContext);
            }
        } catch (Exception e) {
            LoggerService.log('ERROR', 'Org registration failed: ' + e.getMessage(), logContext);
        }
    }
}
