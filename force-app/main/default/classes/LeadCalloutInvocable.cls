public with sharing class LeadCalloutInvocable {

    public class Request {
        @InvocableVariable(required=true description='The Lead record ID')
        public Id leadId;
    }

    @InvocableMethod(label='Send Lead to Objection Proof' description='Publishes a platform event to trigger an API callout to Objection Proof for the given Lead records.')
    public static void callout(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        List<LeadCalloutEvent__e> events = new List<LeadCalloutEvent__e>();
        for (Request r : requests) {
            if (r.leadId != null) {
                events.add(new LeadCalloutEvent__e(LeadId__c = r.leadId));
            }
        }

        if (!events.isEmpty()) {
            List<Database.SaveResult> results = EventBus.publish(events);
            for (Database.SaveResult result : results) {
                if (!result.isSuccess()) {
                    String errorMsg = 'Failed to publish LeadCalloutEvent: ';
                    for (Database.Error err : result.getErrors()) {
                        errorMsg += err.getMessage() + ' ';
                    }
                    LoggerService.log('ERROR', errorMsg, 'LeadCalloutInvocable.callout');
                }
            }
        }
    }
}
