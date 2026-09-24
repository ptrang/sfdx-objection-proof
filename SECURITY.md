# Security Architecture — Objection Proof

This document is intended for **Salesforce AppExchange security reviewers**. It explains the security design decisions in the Objection Proof managed package (namespace: `objectionproof`).

---

## External Services

### What external service is called and why

The package makes outbound HTTP calls to a customer-configured AI service (via a named credential) to score sales call recordings. No external endpoint is hardcoded in the package — the URL is set by the admin post-installation in **Setup → Named Credentials → Objection Proof AI API**.

### What data is sent to the external service

The outbound payload (`TaskCalloutService`) sends the following fields from the Task record:

| Field | Type | Purpose |
|---|---|---|
| `Id` | Salesforce Record ID | Correlate the response back to the Task |
| `Subject` | String | Call title for the AI service context |
| `op_recording_url__c` | URL | The recording to be scored |
| `op_call_from__c` | Phone | Caller phone number |
| `op_call_to__c` | Phone | Recipient phone number |
| `WhoId` / `Who.Name` | ID / String | Contact/Lead associated with the Task |
| `OwnerId` / `Owner.Name` | ID / String | Task owner |
| `callbackUrl` | URL | The single-use token URL for the external service to POST results back |

No passwords, credentials, or session tokens from within Salesforce are included in the payload. The `callbackUrl` contains an opaque AES-128 random token (see below).

### How outbound authentication works

Outbound requests go through named credentials (`objproof_namedcred`, `objproof_lead_namedcred`), so endpoint URLs are admin-configured and never hardcoded in Apex. Each request carries:

- `ObjectionProof-Token` header (n8n) or `api_key` body field (Objection Proof platform): the subscriber's Objection Proof API key, read from the **protected hierarchy custom setting** `Secure_Setting__c.Api_Key__c`
- `Salesforce-Org-Id` header: `UserInfo.getOrganizationId()`, which identifies the source org

The API key is entered by an admin on the Objection Proof setup tab (`SetupWizardController.saveApiKey`). The field is write-only from the UI: the key is never returned to the browser. Because the custom setting is `Protected`, subscriber admins cannot read it through Setup, SOQL, or the API; only package Apex can. No key is shipped in package metadata.

---

## Inbound Callback Security

### Authentication mechanism

The external service calls back to a **Force.com Site** (not an authenticated Salesforce endpoint). The URL contains a single-use, cryptographically random token:

```
{site-url}/services/apexrest/objectionproof/v1/task-callback/{token}
```

**Token generation** (`TaskTriggerHandler.onBeforeUpdate`):
```apex
String token = EncodingUtil.base64Encode(Crypto.generateAesKey(128));
newTask.op_callback_token__c = token.replace('+', '-').replace('/', '_').replace('=', '');
```

- `Crypto.generateAesKey(128)` produces 16 bytes (128 bits) of cryptographically secure random data
- Base64-URL-safe encoding yields a ~22-character opaque token
- 128-bit entropy makes brute-force guessing computationally infeasible

**Token validation** (`TaskCallbackService.updateTaskScore`):
- The token is looked up in `op_callback_token__c` — a SOQL bind variable (no dynamic SOQL, no injection risk)
- The task record is retrieved only if the exact token matches
- If the task already has a score (`op_call_score__c != null`), the request is rejected with HTTP 410
- On success, `op_callback_token__c` is set to `null` — the token is single-use and cannot be replayed

**Input validation:**
- Blank or oversized tokens (>256 chars) are rejected with HTTP 400 before any database query
- User-supplied token values are never reflected back in responses (XSS prevention)
- Exception details are not exposed in API responses

### Why `without sharing` on `TaskCallbackService`

The inbound REST endpoint runs as the **ObjProof site guest user**. Salesforce does not permit guest users to have `edit` object permissions on standard objects (including Task). The class is declared `without sharing` so that sharing rules (which are inapplicable to a guest user with no org access) do not prevent the record lookup.

The token-based lookup (`WHERE op_callback_token__c = :token`) provides the equivalent of record-level access control: the caller can only affect the exact Task whose token they possess.

### Why `AccessLevel.SYSTEM_MODE` for the DML update

Guest users cannot hold edit permissions on Task. To write scores back to the Task after validating the token, the DML is executed with `AccessLevel.SYSTEM_MODE` (available from API 57.0+), which bypasses CRUD/FLS enforcement for that single operation. This is the Salesforce-recommended pattern for guest-user REST endpoints that need to write standard object records.

---

## Sharing Declarations

Every Apex class has an explicit sharing declaration. Justifications for `without sharing`:

| Class | Declaration | Justification |
|---|---|---|
| `TaskTriggerHandler` | `with sharing` | Runs in user context; standard sharing applies |
| `CallActivityService` | `with sharing` | Runs as the OAuth integration user; all queries and DML in `USER_MODE` |
| `SetupWizardController` | `with sharing` | Runs as the admin; all queries and DML in `USER_MODE`, changes gated by the `Manage_Objection_Proof` custom permission |
| `TaskCallbackService` | `without sharing` | Guest user context; token validates record access (see above) |
| `TaskCalloutService`, `LeadCalloutService`, `QueueCallService` | `without sharing` | Queueables run as the Automated Process User (system context); record sets are already gated by the trigger or event |
| `TaskCalloutEventHandler`, `LeadCalloutEventHandler`, `QueueCallEventHandler` | `without sharing` | Platform event subscribers run as the Automated Process User |
| `PostInstallScript` | `without sharing` | Install handler runs as the package installation user; assigns only this package's permission sets |
| `LoggerService`, `LogQueueable` | `with sharing` | Log inserts use `SYSTEM_MODE` because callers (reps, Automated Process, guest) have no `Log__c` access; only admins can read logs |
| `SettingsService` | `with sharing` | Reads package configuration in `SYSTEM_MODE` (no user data); writes the protected API key setting only after the caller's permission check |

---

## SOQL and DML Security

### Dynamic SOQL
The package contains **no dynamic SOQL**. All queries use static SOQL with bind variables.

### FLS enforcement
Every query and DML statement declares its access mode explicitly (`WITH USER_MODE` / `AccessLevel.USER_MODE`, or `SYSTEM_MODE` with a justification comment in the code).

- `CallActivityService`, `SetupWizardController`: `USER_MODE` throughout
- `TaskCallbackService`: `SYSTEM_MODE` (guest user; see above)
- `TaskCalloutService`, `LeadCalloutService`, `QueueCallService`: `SYSTEM_MODE` (Automated Process User)
- `LoggerService`: `SYSTEM_MODE` insert of `Log__c`
- `TaskTriggerHandler`: `SYSTEM_MODE` read of `Site`/`SiteDetail` to build the public callback URL

Code Analyzer findings on the `SYSTEM_MODE` statements are documented as false positives in [`docs/security-review/false-positives.md`](docs/security-review/false-positives.md).

### CRUD enforcement
- No user-context class performs DML on objects without the running user having appropriate permissions via the assigned permission set
- System-context classes (`TaskCalloutService`, `TaskCalloutEventHandler`) do not perform DML on user-accessible records

---

## Credential Management

- **No credentials, tokens, API keys, or PII are hardcoded** in package source code or deployed metadata
- The Objection Proof API key is stored in the protected custom setting `Secure_Setting__c` (not Custom Metadata). It is set post-installation from the setup tab, is never returned to the client, and is readable only by package code
- `Log__c` never records secrets: request bodies (which contain the callback token) and raw API responses are not logged
- The named credential endpoint URL is set to a placeholder and must be configured post-installation
- All outbound callouts use `callout:objectionproof__objproof_namedcred` (named credential reference) — no hardcoded URLs in Apex

---

## Guest User Scope

The **ObjProof Profile** guest user has the minimum permissions necessary:

- **Apex class access**: `TaskCallbackService` only
- **No object or field permissions** at all
- Site settings: Aura requests disabled, standard pages/search/lookups disabled, clickjack protection `SameOriginOnly`

The guest user cannot browse, query, or modify any org data beyond the token-validated Task update executed by `TaskCallbackService`.

---

## Inbound Call Activity (OAuth)

`CallActivityService` (`POST /services/apexrest/objectionproof/v1/call-activity`) is **not** exposed on the Site. The Objection Proof platform calls it with an OAuth access token obtained through the packaged external client app `Objection_Proof_AI`, as a dedicated integration user. Salesforce authenticates the request before Apex runs.

- The integration user holds `objproof_integration_permission_set`: class access to `CallActivityService` plus the minimum object and field access it needs (read Account/Contact; read/create/edit Lead; read/edit Opportunity; create Task; create `op_Call_Analysis__c`)
- All SOQL, SOSL and DML run in `USER_MODE`, so the integration user's CRUD, FLS and sharing are enforced
- The request runs in a savepoint and rolls back entirely on any failure
- Request bodies over 500 KB are rejected (413); error details go to the admin-only log, not to the caller
- Requests are idempotent on `external_call_id` (a unique field on `op_Call_Analysis__c`), so retries can't create duplicate records

---

## Data at Rest

| Data | Storage Location | Who Can Access |
|---|---|---|
| Recording URL | `Task.op_recording_url__c` | Users with `objproof_permission_set` |
| Callback token | `Task.op_callback_token__c` | Users with `objproof_permission_set`; nullified after use |
| Call scores | `Task.op_call_score*__c` | Users with `objproof_permission_set` |
| Transcript | `Task.op_transcript__c` | Users with `objproof_permission_set` |
| Log records | `Log__c` | Users with `objproof_permission_set`; disabled by default |

No data is stored outside of the installing org. The external AI service is provided by the admin and is not operated by the package publisher.

---

## Platform Event Architecture

Outbound callouts are initiated via a **HighVolume Platform Event** (`TaskCalloutEvent__e`) rather than directly from the trigger. This design:

1. Decouples the callout from the triggering user's session — the callout runs as the **Automated Process User**, which is assigned the named credential permission separately
2. Eliminates the need for regular users to hold External Credential Principal permissions
3. Prevents governor limit issues (callouts in triggers)

The event carries only `TaskId__c` (a record ID) and `OrgUrl__c` (the computed site URL). No PII or sensitive data travels in the platform event payload.
