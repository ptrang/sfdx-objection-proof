trigger LeadCalloutEventTrigger on LeadCalloutEvent__e (after insert) {
    LeadCalloutEventHandler.handleEvents(Trigger.new);
}
