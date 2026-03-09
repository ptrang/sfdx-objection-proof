public with sharing class QueueCallTriggerHandler {

    public static void onLeadAfterUpdate(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        List<QueueCallEvent__e> events = new List<QueueCallEvent__e>();

        for (Lead l : newLeads) {
            Lead old = oldMap.get(l.Id);
            // Only fire when status changes TO "call" — prevents re-trigger when set to "queued"/"failed".
            if (l.op_ai_call_status__c == 'call' && old.op_ai_call_status__c != 'call') {
                events.add(new QueueCallEvent__e(
                    RecordId__c = l.Id,
                    ObjectType__c = 'Lead'
                ));
            }
        }

        publishEvents(events);
    }

    public static void onOpportunityAfterUpdate(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {
        List<QueueCallEvent__e> events = new List<QueueCallEvent__e>();

        for (Opportunity o : newOpps) {
            Opportunity old = oldMap.get(o.Id);
            if (o.op_ai_call_status__c == 'call' && old.op_ai_call_status__c != 'call') {
                events.add(new QueueCallEvent__e(
                    RecordId__c = o.Id,
                    ObjectType__c = 'Opportunity'
                ));
            }
        }

        publishEvents(events);
    }

    private static void publishEvents(List<QueueCallEvent__e> events) {
        if (events.isEmpty()) { return; }

        List<Database.SaveResult> results = EventBus.publish(events);
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                String errorMsg = 'Failed to publish QueueCallEvent: ';
                for (Database.Error err : result.getErrors()) {
                    errorMsg += err.getMessage() + ' ';
                }
                LoggerService.log('ERROR', errorMsg, 'QueueCallTriggerHandler.publishEvents');
            }
        }
    }
}
