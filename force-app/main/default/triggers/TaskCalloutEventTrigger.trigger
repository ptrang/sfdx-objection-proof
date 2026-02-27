trigger TaskCalloutEventTrigger on TaskCalloutEvent__e (after insert) {
    TaskCalloutEventHandler.handleEvents(Trigger.new);
}
