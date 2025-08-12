# ObjectionProof - Managed Package

This repository contains the source code for the ObjectionProof managed package. The package provides a webhook-based integration for analyzing task recordings. When a `recording_url` is added to a Task, the package calls an external service and provides a secure callback URL. The external service can then call back to Salesforce to update the Task with an analysis score.

## Components

* **Namespace**: `objectionproof`
* **Custom SObject**: `objectionproof__Task__c` (extensions to the standard Task object)
* **Custom Fields**:
    * `objectionproof__recording_url__c`
    * `objectionproof__callback_token__c`
    * `objectionproof__call_score__c`
* **Custom Setting**: `objectionproof__ObjectionProof_Settings__c` for post-install configuration.
* **Apex Classes**: `TaskTriggerHandler`, `TaskCalloutService`, `TaskCallbackService` (all namespaced).

## Managed Package Installation & Setup

### 1. Create the Package

First, you must create the managed package and the first version from your Dev Hub org.

```bash
# Authorize your Dev Hub
sfdx auth:web:login --set-default-dev-hub --alias MyDevHub

# Create the managed package (only needs to be done once)
# The namespace from sfdx-project.json will be linked to your Dev Hub.
sfdx force:package:create --name "ObjectionProof" --description "Task Recording Analysis" --path force-app --package-type Managed

# The command will return a Package ID (0Ho...). Add this to sfdx-project.json under packageAliases.
# "ObjectionProof": "0Ho..."

# Create the first package version
sfdx force:package:version:create --package "ObjectionProof" --installation-key-bypass --wait 10 --code-coverage