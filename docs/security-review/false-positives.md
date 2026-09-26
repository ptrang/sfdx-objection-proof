# Code Analyzer False Positives — Objection Proof

Salesforce Code Analyzer 5.3, rule selectors `Security` and `AppExchange`, run against `force-app/` for released version **1.13.0**. 16 findings remain: 1 severity 1 and 15 severity 2. Each is explained below. The report is `submission/code-analyzer-1.13.0.html`.

Architecture background is in [`SECURITY.md`](../../SECURITY.md).

---

## 1. `CallActivityService`: `ApexFlsViolation` (5 findings)

| Line | Operation |
|---|---|
| `insert newLead` | INSERT Lead (Company, LeadSource, Phone, LastName) |
| `insert t` | INSERT Task (ActivityDate, Description, op_recording_url__c, …) |
| `insert analysis` | INSERT op_Call_Analysis__c |
| `update l` | UPDATE Lead (op_ai_call_* fields) |
| `update o` | UPDATE Opportunity (op_ai_call_* fields) |

**Why this is a false positive:** each of these statements is executed as `Database.insert(record, AccessLevel.USER_MODE)` or `Database.update(record, AccessLevel.USER_MODE)`. User mode enforces the running user's object permissions, field-level security and sharing on every field being written, and throws if any are missing. The Graph Engine doesn't recognize the `AccessLevel` argument as an FLS check.

Every query in the class also uses `WITH USER_MODE`, and the class is `with sharing`.

**Test evidence:** `CallActivityServiceTest.testUserWithoutPermissionSetIsRejected` runs the endpoint as a user without `objproof_integration_permission_set`. User mode blocks the write, the request returns 400, and the savepoint rolls back the partial work.

**Context:** the endpoint is not exposed to guest users. It is called over OAuth by a dedicated integration user holding `objproof_integration_permission_set`.

---

## 2. `TaskCallbackService`: `ApexFlsViolation` (3) and `DatabaseOperationsMustUseWithSharing` (3)

| Line | Operation |
|---|---|
| Token lookup | READ Task WHERE op_callback_token__c = :token |
| Score update | UPDATE Task (score fields, token cleared) |
| Analysis insert | INSERT op_Call_Analysis__c |

**Why this is by design:** this REST endpoint is served on the ObjProof Force.com Site and is called by the external scoring service as the **Site guest user**, without OAuth.

- Salesforce does not allow guest users to hold edit permission on Task, so a user-mode update is impossible. The class is `without sharing` and uses `SYSTEM_MODE` explicitly (`WITH SYSTEM_MODE` / `AccessLevel.SYSTEM_MODE`).
- The guest user has **no object or field permissions at all**. `objproof_site_permission_set` grants only Apex class access to `TaskCallbackService`.
- Access is authorized by a single-use callback token instead of a user identity:
  - 128 bits from `Crypto.generateAesKey(128)`, generated per Task when the recording URL is set
  - matched exactly with a bind variable (no dynamic SOQL)
  - cleared on first use; a Task that already has a score returns 410
  - never logged, and never echoed in responses
- The service reads and writes only the one Task matching the token, plus its `op_Call_Analysis__c` child. Error responses never include exception details.

**Test evidence:** `TaskCallbackServiceTest` covers the success path, an invalid token (404, token not reflected), a blank token (400), an already-used token (410) and a malformed body (400).

---

## 3. `PostInstallScript`: `AvoidGlobalInstallUninstallHandlers` (1, severity 1), `ApexFlsViolation` (2), `DatabaseOperationsMustUseWithSharing` (2)

**Why `global`:** `PostInstallScript` implements `InstallHandler` and has been `global` in every released version, including 1.10.0 and 1.13.0. Salesforce doesn't allow reducing the access level of a released `global` class, so it can't become `public`. The class exposes one method, `onInstall(InstallContext)`, and it takes no caller input.

**Why system mode, without sharing:** Salesforce runs install handlers as a special package installation user, not as the installer, so user-mode CRUD, FLS and sharing checks don't apply. Every query and DML statement declares `WITH SYSTEM_MODE` or `AccessLevel.SYSTEM_MODE` explicitly. The script only reads this package's own permission sets and existing assignments, then assigns them to the installer and, if the ObjProof Site already exists, to its guest user. It writes one `Log__c` summary row per install.

**Test evidence:** `PostInstallScriptTest` (via `Test.testInstall`) and a fresh install of 1.13.0 in a customer-like org, where the installer received both permission sets.

---

## Findings fixed before submission

The first scan found 49 issues (1 severity 1). The following were fixed rather than justified:

- `PostInstallScript` changed from `global` to `public` (`AvoidGlobalInstallUninstallHandlers`)
- `SetupWizardController`: every query and DML moved to `USER_MODE`; changes gated by the `Manage_Objection_Proof` custom permission
- `CallActivityService` moved off the guest Site to OAuth, `with sharing` and `USER_MODE`
- Access mode declared explicitly (`SYSTEM_MODE` plus a justification comment) in `SettingsService`, `LoggerService`, `LogQueueable`, `TaskTriggerHandler` and `PostInstallScript`
