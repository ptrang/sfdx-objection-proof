// without sharing: platform event subscribers run as the Automated Process User.
// Sharing rules are not applicable in this system-level trigger context.
public without sharing class OrgRegistrationEventHandler {

    public static void handleEvents(List<OrgRegistrationEvent__e> events) {
        // Several saves in one batch still need only one registration.
        if (!events.isEmpty()) {
            System.enqueueJob(new OrgRegistrationService());
        }
    }
}
