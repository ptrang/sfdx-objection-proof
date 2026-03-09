// without sharing: platform event subscribers run as the Automated Process User.
// Sharing rules are not applicable in this system-level trigger context.
public without sharing class QueueCallEventHandler {

    public static void handleEvents(List<QueueCallEvent__e> events) {
        List<QueueCallService.QueueCallRequest> requests = new List<QueueCallService.QueueCallRequest>();

        for (QueueCallEvent__e event : events) {
            requests.add(new QueueCallService.QueueCallRequest(
                (Id) event.RecordId__c,
                event.ObjectType__c,
                event.CallType__c
            ));
        }

        if (!requests.isEmpty()) {
            System.enqueueJob(new QueueCallService(requests));
        }
    }
}
