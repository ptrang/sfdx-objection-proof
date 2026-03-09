trigger LeadTrigger on Lead (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        QueueCallTriggerHandler.onLeadAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
