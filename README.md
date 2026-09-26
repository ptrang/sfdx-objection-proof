# Objection Proof — Salesforce Managed Package

Salesforce managed package (namespace: `objectionproof`) that integrates with an external AI service to score sales calls. When a Task's recording URL is set, Salesforce sends the recording metadata to the external service; the service scores the call and posts results back via a secure, token-authenticated webhook callback.

## How It Works

```
Task updated (op_recording_url__c set)
  → TaskTrigger (before update)
      → generates AES-128 single-use callback token → op_callback_token__c
  → TaskTrigger (after update)
      → publishes TaskCalloutEvent__e platform event
  → TaskCalloutEventTrigger (Automated Process User)
      → enqueues TaskCalloutService (Queueable)
  → TaskCalloutService
      → HTTP POST to external AI service via named credential
      → payload includes callbackUrl with the single-use token
  → External service processes recording, then:
      → PATCH {siteUrl}/services/apexrest/objectionproof/v1/task-callback/{token}
  → TaskCallbackService (Force.com Site, guest user)
      → validates token, writes scores to Task, nullifies token (single-use)
```

The inbound callback uses a **Salesforce Force.com Site** (guest user access) so the external service does **not** need OAuth credentials to call back. The AES-128 token is the sole inbound authentication mechanism and is invalidated after first use.

---

## Installation

### 1. Install the managed package

Install the latest released version, **1.13.0**:
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000W6zxQAC (use `test.salesforce.com` for sandboxes)

The `PostInstallScript` runs automatically. It gives the installer the **Objection Proof** and **Objection Proof Admin** permission sets, and assigns the Site guest-user permission set if the ObjProof Site already exists (on upgrades). Each install writes a one-line summary to the Objection Proof log.

### 2. Create and activate the ObjProof Site

`CustomSite` metadata cannot be included in a managed package. The site must be created and deployed separately, then activated by an admin.

**Option A — Deploy via CLI** (from the repo's `setup/` directory):
```bash
sf project deploy start --source-dir setup --target-org <your-org-alias>
```
Then go to **Setup → Sites → ObjProof → Activate**.

**Option B — Create manually in Setup:**
1. Go to **Setup → User Interface → Sites and Domains → Sites**
2. If prompted, register a **Site Domain** for your org first
3. Click **New** and configure:
   - **Site Label**: `ObjProof`
   - **Site Name**: `ObjProof`
   - **Default Web Address** (URL path prefix): `objproof`
   - **Active Site Home Page**: `ObjProofIndex`
4. Click **Save**, then click **Activate**

After activation, note the **Site URL** (e.g. `https://yourorg.my.site.com/objproof`).

The inbound callback URL your external service will use is:
```
{Site URL}/services/apexrest/objectionproof/v1/task-callback/{token}
```

> **If the guest user permission set was not auto-assigned** (e.g. this is a fresh install and the site was inactive during package install), run the following in **Developer Console → Execute Anonymous**:
> ```apex
> List<User> g = [SELECT Id FROM User WHERE Profile.Name = 'ObjProof Profile' AND IsActive = true LIMIT 1];
> Id ps = [SELECT Id FROM PermissionSet WHERE Name = 'objproof_site_permission_set' LIMIT 1].Id;
> insert new PermissionSetAssignment(AssigneeId = g[0].Id, PermissionSetId = ps);
> ```

### 3. Assign the Automation Permission Set to the Automated Process User

Outbound HTTP callouts run as the **Automated Process** user (via platform events). This user needs access to the named credential.

1. Go to **Setup → Users → Users**
2. In the **View** dropdown select **Automated Process User** and click **Go**
3. Click on the **Automated Process** user
4. Under **Permission Set Assignments**, click **Edit Assignments**
5. Add **Objection Proof Automation Permission Set** (`objproof_automation_permission_set`)
6. Click **Save**

### 4. Configure the Named Credential (endpoint URL)

1. Go to **Setup → Security → Named Credentials**
2. Find **Objection Proof AI API** and click **Edit**
3. Set the **URL** to your external AI service webhook endpoint
4. Click **Save**

### 5. Set the Objection Proof API key

1. Open the **Objection Proof** app and go to the **Objection Proof** setup tab (requires the **Objection Proof Admin** permission set, which the installer gets automatically)
2. In step 3, paste your API key from the Objection Proof dashboard and click **Save**

The key is stored in a protected custom setting and can't be viewed after saving; use **Replace** to change it. Every outbound request sends it (`ObjectionProof-Token` header to n8n, `api_key` in the platform request body), along with a `Salesforce-Org-Id` header.

### 6. Connect the Objection Proof platform (OAuth integration user)

The platform logs AI-made calls into Salesforce through the `call-activity` REST endpoint, authenticated with OAuth through the packaged **Objection Proof AI** external client app.

1. Create a dedicated integration user (for example with the **Salesforce Integration** license and the **Minimum Access - API Only Integrations** profile)
2. Assign it the **Objection Proof Integration** permission set (`objproof_integration_permission_set`). The profile must also allow **Edit Tasks**
3. Make sure it can see and edit the Leads and Opportunities the platform will match (the permission set grants View All on Lead, Contact and Opportunity; edit access follows your sharing settings)
4. Go to **Setup → External Client App Manager → Objection Proof AI → Policies**, enable the **client credentials flow**, and set **Run As** to the integration user
5. Give the platform your My Domain URL; it calls `https://<your-domain>.my.salesforce.com/services/apexrest/objectionproof/v1/call-activity`

---

## Verifying the Installation

### Check site and permissions

```apex
// Verify site is active
System.debug([SELECT Status FROM Site WHERE UrlPathPrefix = 'objproof'].Status);

// Verify guest user has the permission set
User g = [SELECT Id FROM User WHERE Profile.Name = 'ObjProof Profile' AND IsActive = true LIMIT 1];
System.debug([SELECT Id FROM PermissionSetAssignment
              WHERE AssigneeId = :g.Id
              AND PermissionSet.Name = 'objproof_site_permission_set'].size());
```

### End-to-end test

Because `op_recording_url__c` is an Activity-backed custom field, it can only be set from within compiled Apex (not anonymous Apex or the REST API). Test using a real Task update via the UI or a Salesforce Flow that sets the recording URL.

Once a Task has a recording URL set:

1. The **Callback Token** field (`op_callback_token__c`) should populate within seconds
2. Query the token via SOQL in Developer Console:
```apex
Task t = [SELECT objectionproof__op_callback_token__c
          FROM Task
          WHERE objectionproof__op_recording_url__c != null
          ORDER BY LastModifiedDate DESC LIMIT 1];
System.debug(t.objectionproof__op_callback_token__c);
```

3. Make a test callback using the token:
```bash
curl -X PATCH \
  "{Site URL}/services/apexrest/objectionproof/v1/task-callback/{token}" \
  -H "Content-Type: application/json" \
  -d '{
    "salescall_id": "test-9999",
    "transcript": "Test transcript",
    "evaluation": "https://example.com/eval/9999",
    "score": 75,
    "revenue": 1250,
    "opening": 8, "engagement": 7, "nonneedy": 8, "guiding": 7,
    "closing": 6, "assertiveness": 7, "empathy": 8,
    "stories": 5, "objection": 6, "remorse": 8
  }'
```

Expected responses:
- `HTTP 204` — success, Task updated, token nullified
- `HTTP 404` — token not found or already used
- `HTTP 400` — malformed token or request body

4. Confirm the Task score fields are populated and `op_callback_token__c` is now blank

---

## Application Configuration

This package uses Custom Metadata for runtime configuration. Settings are managed under **Setup → Custom Metadata Types → Objection Proof Setting**.

| Setting | Default | Purpose |
|---|---|---|
| `Callout_Source` | `sf-bolder360` | Value sent as `source` in call scoring requests to n8n |
| `Logging_Enabled` | *(not set)* | Set to `true` to write `Log__c` records (see below) |

The API key is **not** stored here; see step 5 of Installation.

### Enable Logging

Logging is **disabled by default**. To enable:

1. Go to **Setup → Custom Metadata Types**
2. Click **Manage Records** next to **Objection Proof Setting** (`Application_Setting__mdt`)
3. Click **New** and set:
   - **Label**: `Logging Enabled`
   - **Application Setting Name**: `Logging_Enabled`
   - **Value**: `true`
4. Click **Save**

Logs are written to `objectionproof__Log__c` and can be queried via:
```soql
SELECT objectionproof__Level__c, objectionproof__Context__c,
       objectionproof__Message__c, CreatedDate
FROM objectionproof__Log__c
ORDER BY CreatedDate DESC
LIMIT 50
```

---

## Permission Sets

| Permission Set | Assign To | Purpose |
|---|---|---|
| `objproof_admin_permission_set` | Objection Proof admins *(auto-assigned to installer)* | Setup tab (API key, permission set assignment) and read access to logs |
| `objproof_permission_set` | Regular users | Read/write access to `op_*` fields on Task and Event; Apex class access |
| `objproof_automation_permission_set` | **Automated Process User** | Named credential principal access for outbound callouts |
| `objproof_integration_permission_set` | The **integration user** the Objection Proof platform signs in as (OAuth) | `call-activity` endpoint and the Lead/Contact/Opportunity/Task access it needs |
| `objproof_site_permission_set` | Site guest user *(auto-assigned on install)* | `TaskCallbackService` class access only; no object or field access |

> **Note on guest user permissions:** The guest user has no object or field access. The callback service reads and writes the one Task matching the callback token using `SYSTEM_MODE`, because Salesforce does not permit guest users to hold edit permissions on standard objects.

---

## Security Architecture

See [`SECURITY.md`](SECURITY.md) for a detailed explanation of the security design, intended for AppExchange security reviewers.
