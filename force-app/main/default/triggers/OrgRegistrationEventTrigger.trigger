trigger OrgRegistrationEventTrigger on OrgRegistrationEvent__e (after insert) {
    OrgRegistrationEventHandler.handleEvents(Trigger.new);
}
