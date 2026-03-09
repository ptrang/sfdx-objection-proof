trigger QueueCallEventTrigger on QueueCallEvent__e (after insert) {
    QueueCallEventHandler.handleEvents(Trigger.new);
}
