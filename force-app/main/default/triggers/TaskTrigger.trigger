trigger TaskTrigger on Task (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        TaskTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}