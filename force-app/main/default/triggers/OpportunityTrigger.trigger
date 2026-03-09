trigger OpportunityTrigger on Opportunity (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        QueueCallTriggerHandler.onOpportunityAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
