# Objection Proof — Salesforce Managed Package

Salesforce managed package (namespace: `objectionproof`) that integrates with an external AI service to score sales calls. When a Task's recording URL is set, Salesforce sends the recording to the external service and receives scored results back via a secure webhook callback.

## How It Works

```
Task updated (recording URL set)
  → TaskTrigger (before update)
      → generates AES-128 single-use callback token
  → TaskTrigger (after update)
      → publishes TaskCalloutEvent__e platform event
  → TaskCalloutEventTrigger
      → enqueues TaskCalloutService (runs as Automated Process user)
  → TaskCalloutService
      → HTTP POST to external service (named credential)
      → payload includes callbackUrl: https://[org].my.site.com/objproof/services/apexrest/objectionproof/v1/task-callback/{token}
  → External service processes recording, then:
      → PATCH /services/apexrest/objectionproof/v1/task-callback/{token}
  → TaskCallbackService
      → validates token, updates Task with scores, nullifies token (single-use)
```

The inbound callback uses a **Salesforce Site** (guest user access) — the external service does **not** need OAuth credentials to call back. The AES-128 token in the URL is the sole authentication mechanism.

---

## Installation

### 1. Install the managed package

Install the latest package version into your org. The package automatically:
- Creates the `ObjProof` Salesforce Site (inactive)
- Assigns the site guest user permission set (Task read/edit + class access)

### 2. Activate the ObjProof Site

The site is deployed inactive because the site admin cannot be set during package installation.

1. Go to **Setup → User Interface → Sites and Domains → Sites**
2. Find **ObjProof** and click **Activate**
3. Confirm the site is now **Active**

The callback URL your external service will receive is:
```
https://[your-org-domain].my.site.com/objproof/services/apexrest/objectionproof/v1/task-callback/{token}
```

### 3. Assign the Automation Permission Set to the Automated Process User

The outbound HTTP callout to the external service runs as the **Automated Process** user (via platform events). This user needs access to the named credential.

1. Go to **Setup → Users → Users**
2. In the **View** dropdown, select **Automated Process User** and click **Go**
3. Click on the **Automated Process** user
4. Under **Permission Set Assignments**, click **Edit Assignments**
5. Add **Objection Proof Automation Permission Set** (`objproof_automation_permission_set`)
6. Click **Save**

### 4. Configure the Named Credential

The named credential holds the URL for the external AI service that processes recordings.

1. Go to **Setup → Security → Named Credentials**
2. Find **objproof_namedcred** and click **Edit**
3. Set the **URL** to your external service endpoint
4. Click **Save**

---

## Verifying the Installation

### Check site permissions

If callbacks return permission errors, verify the guest user has the correct object access:

1. **Setup → Sites → ObjProof → Public Access Settings**
2. Under **Object Settings → Tasks**, confirm Read and Edit are enabled
3. Confirm `objectionproof.TaskCallbackService` appears under **Enabled Apex Class Access**

If these are missing, run the following in **Developer Console → Execute Anonymous**:

```apex
List<User> guestUsers = [SELECT Id FROM User WHERE Profile.Name = 'ObjProof Profile' AND IsActive = true LIMIT 1];
Id psId = [SELECT Id FROM PermissionSet WHERE Name = 'objproof_site_permission_set' LIMIT 1].Id;
insert new PermissionSetAssignment(AssigneeId = guestUsers[0].Id, PermissionSetId = psId);
System.debug('Assigned permission set to guest user: ' + guestUsers[0].Id);
```

### End-to-end test

1. Create or update a Task and set the **Recording URL** field
2. The **Callback Token** field should auto-populate within seconds
3. Query the token:

```apex
Task t = [SELECT op_callback_token__c FROM Task WHERE op_recording_url__c != null ORDER BY LastModifiedDate DESC LIMIT 1];
System.debug('Token: ' + t.op_callback_token__c);
```

4. Make a test callback using the token:

```bash
curl -X PATCH \
  "https://[your-org-domain].my.site.com/objproof/services/apexrest/objectionproof/v1/task-callback/{token}" \
  -H "Content-Type: application/json" \
  -d '{
    "salescall_id": 9999,
    "status": "processed",
    "transcript": "Test transcript",
    "evaluation": "https://example.com/eval/9999",
    "score": 75,
    "opening": 8, "engagement": 7, "nonneedy": 8, "guiding": 7,
    "closing": 6, "assertiveness": 7, "empathy": 8,
    "stories": 5, "objection": 6, "remorse": 8
  }'
```

Expected response: `HTTP 204 No Content`

5. Confirm the Task now has score fields populated and **Callback Token** is blank

---

## Application Configuration

This package uses Custom Metadata for configuration. Settings are managed under **Setup → Custom Metadata Types → Objection Proof Setting**.

### Enable Logging

Logging is **disabled by default**. To enable:

1. Go to **Setup → Custom Metadata Types**
2. Click **Manage Records** next to **Objection Proof Setting**
3. Click **New** and set:
   - **Label**: `Logging Enabled`
   - **Application Setting Name**: `Logging_Enabled`
   - **Value**: `true`
4. Click **Save**

To disable, set the **Value** to `false` or delete the record.

Logs are written to the `objectionproof__Log__c` custom object and can be viewed under the **Log** tab (if added to your app) or via SOQL:

```soql
SELECT objectionproof__Level__c, objectionproof__Context__c, objectionproof__Message__c, CreatedDate
FROM objectionproof__Log__c
ORDER BY CreatedDate DESC
LIMIT 50
```

---

## Permission Sets

| Permission Set | Assign To | Purpose |
|---|---|---|
| `objproof_permission_set` | Regular users | Field access to `op_*` fields on Task/Event, Apex class access |
| `objproof_automation_permission_set` | **Automated Process User** | Named credential access for outbound HTTP callouts |
| `objproof_site_permission_set` | Site guest user *(auto-assigned on install)* | Task read/edit + `TaskCallbackService` access for inbound callbacks |
