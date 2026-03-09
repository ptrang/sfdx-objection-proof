// without sharing: platform event subscribers run as the Automated Process User.
// Sharing rules are not applicable in this system-level trigger context.
public without sharing class LeadCalloutEventHandler {

    public static void handleEvents(List<LeadCalloutEvent__e> events) {
        Set<Id> leadIds = new Set<Id>();

        for (LeadCalloutEvent__e event : events) {
            leadIds.add((Id) event.LeadId__c);
        }

        if (!leadIds.isEmpty()) {
            System.enqueueJob(new LeadCalloutService(leadIds));
        }
    }
}
