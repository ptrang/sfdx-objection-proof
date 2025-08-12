trigger TaskTrigger on Task (before update, after update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        TaskTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        TaskTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}