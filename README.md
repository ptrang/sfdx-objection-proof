# Salesforce Task Webhook Callback Architecture

This project demonstrates a robust, asynchronous integration pattern. When a Task's `recording_url__c` is populated, Salesforce calls an external service and provides it with a unique, secure, single-use callback URL (a webhook). Once the external service finishes its processing, it calls this URL back to update the original Task with a `call_score__c`.

## How It Works

![Webhook Callback Flow](https://i.imgur.com/8QG34X5.png)

1.  **Trigger Fires (`before update`)**: A user updates a Task with a `recording_url__c`. The `before update` trigger fires.
2.  **Token Generation**: The `TaskTriggerHandler` generates a cryptographically secure, unique token and saves it in the `Task.callback_token__c` field before the record is committed to the database.
3.  **Asynchronous Callout (`after update`)**: After the record saves, the `after update` trigger fires and calls the `TaskCalloutService` future method.
4.  **Outbound POST**: This service sends the `recording_url__c` **and** the newly generated `callbackUrl` (e.g., `https://my-site.my.salesforce-sites.com/services/apexrest/v1/task-callback/{token}`) to the external system.
5.  **External Processing**: The external system processes the recording at its own pace.
6.  **Inbound Webhook Callback**: Once finished, the external system makes a `PATCH` request to the `callbackUrl` it received, including the score in the JSON body (e.g., `{"score": 95}`).
7.  **Apex REST Service**: The public `TaskCallbackService` receives this request. It uses the token from the URL to find the correct Task.
8.  **Secure Update**: The service updates the Task's `call_score__c` and simultaneously **nullifies the `callback_token__c`** to make the URL single-use.

## Setup Instructions

**This architecture requires a Salesforce Site.**

1.  **Clone and Deploy**: Clone the repository and deploy the source to your org.
    ```bash
    sfdx force:source:deploy -p force-app/main/default
    ```

2.  **Create a Salesforce Site**:
    * Go to **Setup -> User Interface -> Sites and Domains -> Sites**.
    * If you don't have a domain, register one.
    * Click **New** to create a new Site.
    * **Label**: `Task Update Service`
    * **Name**: `Task_Update_Service`
    * **Default Web Address**: `task-callback` (or a name of your choice)
    * **Active Site Home Page**: Choose any Visualforce page (e.g., `Unauthorized`); it doesn't matter for this REST service.
    * Check the **Active** box and **Save**.

3.  **Configure Public Access Settings**:
    * On the Site Details page, click **Public Access Settings**.
    * Under **Enabled Apex Class Access**, click **Edit**.
    * Add `TaskCallbackService` to the list of enabled classes and **Save**.
    * Go back to the profile and find **Object Settings**.
    * Select **Tasks**. Click **Edit**.
    * Give the profile **Edit** access to the Task object.
    * Under Field Permissions, grant **Edit Access** to the `Call Score` and `Callback Token` fields. **Save**.

4.  **Update Named Credential**:
    * Go to **Setup -> Security -> Named Credentials**.
    * Edit the `Recording_Service` and provide the real URL for your external processing service.

5.  **Test**:
    * Create or update a Task with a `Recording URL`.
    * The `Callback Token` field should auto-populate upon saving.
    * Use a tool like Postman or `curl` to simulate the external service's callback. Make a `PATCH` request to your Site URL (`https://YOUR_SITE_DOMAIN/task-callback/services/apexrest/v1/task-callback/{THE_TOKEN_VALUE}`) with a body like `{"score": 95}`.
    * Verify the `Call Score` on the Task is updated and the `Callback Token` is now blank.