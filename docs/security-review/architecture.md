# Objection Proof — Solution Architecture and Data Flow

Prepared for the AgentExchange security review. Package: **Objection Proof** (2GP managed, namespace `objectionproof`), version 1.13.0 (04tgL000000W6zxQAC), API 64.0.

Related documents:
- [`SECURITY.md`](../../SECURITY.md): security controls in detail
- [`false-positives.md`](false-positives.md): Code Analyzer findings and justifications
- [`README.md`](../../README.md): installation and configuration

---

## 1. What the solution does

Objection Proof is an AI sales-coaching platform. The managed package connects a customer's Salesforce org to the Objection Proof services so that:

1. **Call scoring.** When a rep's call Task gets a recording URL, the recording is sent for AI scoring, and the scores and transcript are written back to the Task.
2. **AI outbound calling.** New Leads (through a flow action), and Leads or Opportunities whose AI Call Status is set to `call`, are sent to the Objection Proof platform, which places or queues an AI phone call.
3. **AI call logging.** When the platform's AI caller finishes a call, it logs the call in Salesforce: it matches the prospect, creates a Task and a Call Analysis record, and updates the Lead or Opportunity.

## 2. Components

| Component | Where it runs | Purpose |
|---|---|---|
| Managed package (Apex, LWC, metadata) | Customer's Salesforce org | Triggers, platform events, queueables, three REST endpoints (task-callback, call-activity, api-key), setup tab |
| ObjProof Force.com Site | Customer's Salesforce org (created by the admin from `setup/sites`, not packaged) | Public HTTPS host for the scoring callback endpoint only |
| n8n scoring workflow | Objection Proof's n8n instance (URL set by the admin in `objproof_namedcred`) | Receives recordings, runs AI scoring, calls back |
| Objection Proof platform | `https://app.objectionproof.ai` (Next.js on Vercel, Supabase Postgres) | AI calling, call queues, customer accounts |
| External Client App `Objection_Proof_AI` | Packaged; OAuth policies set by the customer admin | OAuth client for the platform's inbound requests (call-activity, API key rotation) |

## 3. Data flows

Every connection uses HTTPS (TLS 1.2+). Outbound endpoints are reached only through Named Credentials; no URLs are hardcoded in Apex.

### Flow A: call scoring (Salesforce → n8n → Salesforce)

```
Rep updates Task (op_recording_url__c set)
  → TaskTrigger (before update): generates a 128-bit random callback token on the Task
  → TaskTrigger (after update): publishes TaskCalloutEvent__e
  → TaskCalloutEventTrigger (Automated Process user) enqueues TaskCalloutService
  → TaskCalloutService: POST callout:objproof_namedcred        [A1, outbound]
        n8n downloads the recording and scores it
  ← n8n: PATCH {site}/services/apexrest/objectionproof/v1/task-callback/{token}   [A2, inbound]
  → TaskCallbackService (Site guest user): writes scores, creates op_Call_Analysis__c, clears the token
```

**A1 outbound request** (`TaskCalloutService`)
- Headers: `ObjectionProof-Token` (the customer's API key), `Salesforce-Org-Id`
- Body: `taskId`, `title` (Task Subject), `recordingUrl`, `callbackUrl` (contains the one-time token), `callFrom`, `callTo`, `whoId`, `whoName` (Lead/Contact name), `ownerId`, `ownerName`, `source`

**A2 inbound request** (`TaskCallbackService`)
- Authentication: the one-time token in the URL. It is 128 random bits, matched exactly with a bind variable, and cleared on first use; a Task that already has a score returns 410.
- Body: `salescall_id`, `score`, 10 metric scores, `revenue`, `evaluation_url`, `full_transcript`, `full_evaluation`
- Writes: the matched Task's score fields, plus one new `op_Call_Analysis__c` record

### Flow B: AI outbound calling (Salesforce → platform)

```
New Lead + "Send Lead to Objection Proof" flow action (LeadCalloutInvocable)
  → LeadCalloutEvent__e → LeadCalloutService: POST callout:objproof_lead_namedcred/api/call-lead    [B1]

Lead/Opportunity op_ai_call_status__c changed to "call" (LeadTrigger / OpportunityTrigger)
  → QueueCallEvent__e → QueueCallService: POST callout:objproof_lead_namedcred/api/queue-call      [B2]
  → sets op_ai_call_status__c to "queued" or "failed"
```

**B1 and B2 outbound requests**
- Header: `Salesforce-Org-Id`
- Body: `api_key` (the customer's API key), `lead_phone`, `full_name`, `prospect_email`, `street_address`, `city`, `state`, `zip`, `full_address`; B2 also sends `call_type`
- For Opportunities, contact details come from the primary Opportunity Contact Role (falling back to any contact role)

### Flow C: AI call logging (platform → Salesforce)

```
Platform's AI caller finishes a call
  → POST https://{login}/services/oauth2/token   (client credentials, External Client App)   [C1]
  → POST https://{my-domain}/services/apexrest/objectionproof/v1/call-activity                 [C2]
  → CallActivityService (runs as the integration user)
```

- **C1 authentication:** OAuth 2.0 client credentials flow through the packaged External Client App. The customer's admin enables the flow and sets the Run As integration user.
- **C2 authorization:** the integration user holds `objproof_integration_permission_set`. All queries and DML run in `USER_MODE`, so its CRUD, field-level security and sharing apply. The work runs in a savepoint and rolls back entirely on any failure. Bodies over 500 KB are rejected.
- **Body:** `prospect`, `prospect_phone`, `prospect_notes` (Salesforce record Id, when known), `subject`, `summary`, `transcript`, `details`, `call_url`, `outcome`, `appointment`, `email_subject`, `timezone`, `external_call_id` (the platform's call ID)
- **Idempotent:** `external_call_id` is stored in a unique field on `op_Call_Analysis__c`. A retried request for a call that is already recorded returns 200 with the original Task Id and writes nothing.
- **Writes:** it matches a Lead/Contact/Opportunity by Id or SOSL phone search (following converted Leads), or creates a Lead. It then creates a Task and an `op_Call_Analysis__c` record, and updates the `op_ai_call_*` fields on the Lead or Opportunity.

### Flow D: org registration (Salesforce → platform)

```
Admin saves the API key on the Setup tab (SetupWizardController.saveApiKey)
  → OrgRegistrationEvent__e (published after commit)
  → OrgRegistrationEventTrigger (Automated Process user) enqueues OrgRegistrationService
  → POST callout:objproof_lead_namedcred/api/integrations/salesforce/register   [D1]
```

- **D1 body:** `api_key`, `org_id` (`UserInfo.getOrganizationId()`), `my_domain` (the org's My Domain host). Header: `Salesforce-Org-Id`.
- **Platform side:** looks up the active client by API key, checks the host against the `*.my.salesforce.com` allowlist, and creates that client's connection row with sending **off**. It never overwrites an existing row. A customer owner or manager reviews the address and turns sending on.

### Flow E: API key rotation (platform → Salesforce)

```
Objection Proof staff rotate a client's key in the admin portal
  → admin portal asks the platform to push it (admin-secret authenticated)
  → platform: POST https://{my-domain}/services/oauth2/token (client credentials)
  → platform: POST https://{my-domain}/services/apexrest/objectionproof/v1/api-key   [E1]
  → ApiKeyService (integration user)
```

- The admin portal never talks to Salesforce; the platform brokers every Salesforce call.
- **E1 body:** `current_api_key`, `new_api_key`. The endpoint updates the protected setting only if `current_api_key` matches the key stored in the org (a SHA-256 digest comparison). An OAuth token alone can't replace the key.
- **Responses:** 204 updated; 200 `unchanged` (an idempotent retry); 403 current key mismatch; 409 no key configured; 400 bad input. Keys are never echoed or logged.

## 4. Identities and permissions

| Identity | Permission set | Can do |
|---|---|---|
| Sales users | `objproof_permission_set` | Read and edit the `op_*` Task/Event fields; read Call Analysis records |
| Objection Proof admins | `objproof_admin_permission_set` (assigned to the installer) | Setup tab, `Manage_Objection_Proof` custom permission, read logs |
| Automated Process user | `objproof_automation_permission_set` | Use the two Named Credentials' principals for outbound callouts |
| ObjProof Site guest user | `objproof_site_permission_set` | Apex class access to `TaskCallbackService` only; no object or field access |
| Integration user (OAuth) | `objproof_integration_permission_set` | `CallActivityService` and `ApiKeyService`, plus read Account/Contact; read/create/edit Lead; read/edit Opportunity; create Task; create Call Analysis |

## 5. Secrets and credentials

| Secret | Stored in | Who can read it |
|---|---|---|
| Objection Proof API key | Protected hierarchy custom setting `Secure_Setting__c.Api_Key__c` | Package Apex only. Admins enter it write-only on the setup tab; it is never returned to the browser. |
| Scoring callback token | `Task.op_callback_token__c`, one per Task | Cleared on first use; never logged or echoed |
| OAuth client credentials | External Client App (consumer key and secret held by Objection Proof); access tokens issued by Salesforce | Not stored in the package |
| n8n endpoint URL | `objproof_namedcred` (admin-configured) | Admins |

No secrets are shipped in package metadata. `Log__c` records never contain request bodies, tokens or raw API responses, and only admins can read them.

## 6. Data stored and sent

- **Stored in Salesforce by the package:** call scores and IDs on Task/Event; AI call status, notes, outcome and appointment on Lead and Opportunity; transcripts, evaluations and summaries in `op_Call_Analysis__c`; operational logs in `Log__c` (off by default).
- **Sent out of Salesforce:** only the fields listed in flows A1, B1 and B2. That is prospect contact details (name, phone, email, address), the call recording URL, and Task and owner names and Ids. No Salesforce credentials or session IDs are ever sent.

## 7. External endpoints in scope for DAST

| Endpoint | Operator | Direction |
|---|---|---|
| n8n scoring webhook (URL in `objproof_namedcred`) | Objection Proof (n8n) | Salesforce → n8n |
| `https://app.objectionproof.ai/api/integrations/salesforce/register` | Objection Proof | Salesforce → platform |
| `https://app.objectionproof.ai/api/call-lead`, `/api/queue-call` | Objection Proof | Salesforce → platform |
| `{site}/services/apexrest/objectionproof/v1/task-callback/{token}` | Customer's Salesforce Site | n8n → Salesforce |
