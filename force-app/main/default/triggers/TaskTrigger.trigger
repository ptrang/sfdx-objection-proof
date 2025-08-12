trigger TaskTrigger on Task (before update, after update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        objectionproof__TaskTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        objectionproof__TaskTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}