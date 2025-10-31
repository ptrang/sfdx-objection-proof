# Salesforce Task Webhook Callback Architecture

This project demonstrates a robust, asynchronous, and decoupled integration pattern. When a Task's `objectionproof__op_recording_url__c` is populated, Salesforce publishes a Platform Event. A trigger subscribing to this event then initiates a callout to an external service, providing it with a unique, secure, single-use callback URL (a webhook). Once the external service finishes its processing, it calls this URL back to update the original Task with analysis data.

## How It Works

![Webhook Callback Flow](https://i.imgur.com/8QG34X5.png)

1.  **Trigger Fires (`before update`)**: A user updates a Task with a `objectionproof__op_recording_url__c`. The `before update` trigger fires.
2.  **Token Generation**: The `TaskTriggerHandler` generates a cryptographically secure, unique token and saves it in the `Task.objectionproof__op_callback_token__c` field.
3.  **Event Publishing (`after update`)**: After the record saves, the `after update` trigger fires. Instead of calling an Apex method directly, it now publishes a `Callout_Request__e` Platform Event. This event contains the Task ID and the secure URL of the Salesforce Site for the callback.
4.  **Platform Event Trigger**: A dedicated trigger, `CalloutRequestTrigger`, is subscribed to the `Callout_Request__e` event. When it receives an event, it enqueues a `TaskCalloutService` job.
5.  **Asynchronous Callout**: The `TaskCalloutService` job queries for the Task details and sends the `objectionproof__op_recording_url__c` and the unique `callbackUrl` to the external system.
6.  **External Processing**: The external system processes the recording at its own pace.
7.  **Inbound Webhook Callback**: Once finished, the external system makes a `PATCH` request to the `callbackUrl` it received, including the analysis data in the JSON body.
8.  **Apex REST Service**: The public `TaskCallbackService` receives this request, finds the correct Task using the token, and updates it.
9.  **Secure Update**: The service updates the Task with the analysis scores and simultaneously **nullifies the `objectionproof__op_callback_token__c`** to make the URL single-use.

## Setup Instructions

**This architecture requires a Salesforce Site and a dedicated user for process automation.**

1.  **Install the Package**: Install the managed package into your org.

2.  **Create a Salesforce Site**:
    * Go to **Setup -> User Interface -> Sites and Domains -> Sites**.
    * If you don't have a domain, register one.
    * Click **New** to create a new Site.
    * **Label**: `Task Update Service`
    * **Name**: `Task_Update_Service`
    * **Default Web Address**: `taskcallback`
    * **Active Site Home Page**: Choose any Visualforce page (e.g., `Unauthorized`); it doesn't matter for this REST service.
    * Check the **Active** box and **Save**.

3.  **Configure a User for Process Automation**:
    * It is a best practice to have a dedicated user for running background automations. Create a new user with a **Salesforce Integration** license and the **Salesforce API Only System Integrations** profile.
    * Go to **Setup -> Permission Sets** and find the **Objection Proof Permission Set** that was included with this package.
    * Click **Manage Assignments**, then **Add Assignments**.
    * Assign this permission set to the dedicated integration user you created.

4.  **Set the Default Workflow User**:
    * Go to **Setup -> Process Automation -> Process Automation Settings**.
    * For the **Default Workflow User**, click the lookup and select the integration user you configured in the previous step. This ensures the Platform Event trigger runs as a user with the correct permissions.

5.  **Configure Public Access for the Site**:
    * On the Site Details page, click **Public Access Settings**.
    * Under **Enabled Apex Class Access**, click **Edit**.
    * Add `objectionproof.TaskCallbackService` to the list of enabled classes and **Save**.
    * Go back to the profile and find **Object Settings**. Grant the necessary field-level security for the Task fields that will be updated by the callback.

6.  **Update Named Credential**:
    * Go to **Setup -> Security -> Named Credentials**.
    * Edit the `objectionproof__objproof_namedcred` and provide the real URL for your external processing service.

7.  **Enable Logging (Optional)**:
    * Go to **Setup -> Custom Metadata Types** and click **Manage Records** next to **Objection Proof Setting**.
    * Create a new record with the **Label** "Logging Enabled", **Name** `Logging_Enabled`, and **Value** set to `true`.