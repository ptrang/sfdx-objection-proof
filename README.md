# Salesforce Task Recording URL Callout

This SFDX project contains the necessary components to listen for changes to a custom field `recording_url__c` on the Task object and send the new URL value in a POST request to an external service.

## How It Works

1.  **TaskTrigger**: An `after update` trigger on the `Task` object.
2.  **TaskTriggerHandler**: The trigger delegates logic to this class. It checks if the `recording_url__c` field has been populated or changed.
3.  **TaskCalloutService**: If a change is detected, the handler calls a `@future(callout=true)` method in this service class.
4.  **HTTP POST**: The future method queries the relevant Task details and makes a POST request to the endpoint defined in the `Recording_Service` Named Credential.

## Components

* **Custom Field**: `Task.recording_url__c` (Type: URL)
* **Apex Trigger**: `TaskTrigger`
* **Apex Classes**:
    * `TaskTriggerHandler`: Logic for the trigger.
    * `TaskCalloutService`: Asynchronous callout logic.
    * `TaskCalloutServiceTest`: Test class with mock callout.
* **Named Credential**: `Recording_Service`

## Setup Instructions

1.  **Clone the Repository**:
    ```bash
    git clone <your-repo-url>
    cd salesforce-task-callout-repo
    ```

2.  **Authorize an Org**:
    Connect this project to a Salesforce org (e.g., a scratch org or a sandbox).
    ```bash
    sfdx auth:web:login --set-default-dev-hub --alias MyDevHub
    sfdx force:org:create -f config/project-scratch-def.json --set-alias MyScratchOrg
    ```
    Or for a sandbox:
    ```bash
    sfdx auth:web:login --set-alias MySandbox --instance-url [https://test.salesforce.com](https://test.salesforce.com)
    ```

3.  **Deploy the Project**:
    ```bash
    # For a scratch org
    sfdx force:source:push

    # For a sandbox or dev org
    sfdx force:source:deploy -p force-app/main/default
    ```

4.  **Configure the Named Credential**:
    * In your Salesforce org, navigate to **Setup -> Security -> Named Credentials**.
    * Click **Edit** next to the "Recording Service" credential.
    * In the **URL** field, enter the actual endpoint URL of the environment you want to send the POST request to (e.g., `https://api.yourexternalservice.com/new-recording`).
    * Click **Save**.

5.  **Test**:
    * Create a new Task.
    * Update the Task by populating the "Recording URL" field with a valid URL.
    * Save the record.
    * Check the logs in your external service to confirm it received a POST request. You can also check the Apex Jobs queue in Salesforce Setup to see the Future method run.
