# AgentExchange submission — paste-ready answers

Package **Objection Proof** 1.13.0, released. Subscriber package version ID **04tgL000000W6zxQAC**.
Install URL: https://login.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000W6zxQAC

Items marked **[YOU]** need a value only you have.

---

## Part 1 — Partner Console setup (do first)

1. **Partner Console → Technologies → Connect Technology**: connect the Dev Hub `patrick738@agentforce.com` (org 00DgL000006LHGv). The package "Objection Proof" (0HogL0000000QKHSA2) then appears under Technologies.
2. **Listings**: open the existing listing (or **New Listing** if it was lost with the trial org), then link the solution to package version **1.13.0**.
3. **License Management App**: in the Partner Business Org, confirm the LMA is installed, then associate the package with the LMA from the Partner Console.

---

## Part 2 — Listing content

**Listing title:**
Objection Proof AI: AI Call Coaching and AI Calling for Sales Cloud

**Tagline (short description):**
Score every sales call with AI, call new leads in seconds, and log every AI call in Salesforce automatically.

**Description:**
> Objection Proof AI turns every sales call into coaching, and puts an AI caller to work on your leads, right inside Sales Cloud.
>
> **Coach every rep on every call.** Attach a call recording to a Task and Objection Proof scores it across 10 coaching metrics: opening, engagement, non-neediness, guiding questions, closing, assertiveness, empathy, stories, objection handling and remorse handling. It also gives an overall score. The scores, transcript and evaluation land on the Task and a Call Analysis record, so managers coach from real calls instead of guesses.
>
> **Call new leads in seconds.** New Leads, and Leads or Opportunities flagged for follow-up, are called by the Objection Proof AI caller. It tells new leads and follow-ups apart automatically.
>
> **Every AI call, logged.** When the AI caller finishes, the call is logged in Salesforce: the prospect is matched (or a Lead is created), and a completed call Task, a Call Analysis record, the outcome and any appointment are recorded.
>
> **Built for admins.** A guided Setup tab handles permission sets, the API key and the connection. Secrets live in protected settings, and every integration uses least-privilege permission sets and OAuth.
>
> Requires an Objection Proof AI subscription.

**Highlights (3):**
1. AI scores every recorded call across 10 coaching metrics, written back to Salesforce.
2. AI outbound calling for new leads and follow-ups, with results logged automatically.
3. Guided setup, protected secrets, and least-privilege, OAuth-secured integrations.

**Categories:** Sales → Sales Intelligence (primary); Sales → Sales Productivity; Sales → Call Center / Telephony
**Industries:** Real Estate; Professional Services
**Supported editions:** Enterprise, Unlimited, Performance, Developer. API access is required for the OAuth integration, so Professional Edition needs the API add-on.
**Supported features:** Lightning Experience. Uses Platform Events, Named Credentials and an External Client App.
**Pricing:** Free. Requires an Objection Proof AI subscription ($15,000 per year, billed by Objection Proof). *(Confirm Free vs Paid with your partner manager; see the open support case.)*
**Support:** in-app chat and email, same-business-day first response. Email: **[YOU: support email]**, hours **[YOU]**
**Company:** Disruptor Solutions Incorporated · Phoenix, Arizona · https://objectionproof.ai
**Media [YOU]:** at least 3 screenshots (the Setup tab, a scored Task with its Call Analysis record, a Lead with AI call status/outcome) and a logo. A 1–2 minute demo video is recommended.

---

## Part 3 — Security review wizard

Start from **Partner Console → Technologies → Solutions → (Objection Proof) → Start Review**.

### Contacts
- Primary: Patrick Trang, patrick@closemoresales.com
- Backup distribution list: **[YOU: a shared mailbox, e.g. security@objectionproof.ai]**

### Technical details
- **Solution type:** managed package (2GP) plus external web services (composite)
- **Namespace:** objectionproof · **Package ID:** 0HogL0000000QKHSA2 · **Version:** 1.13.0 (04tgL000000W6zxQAC)
- **Components:** Apex, Lightning Web Component (the Setup tab), Aura wrapper, custom objects and fields, platform events, triggers, a flow template, permission sets, a custom permission, named and external credentials, an External Client App (OAuth)
- **Mobile app / browser extension in scope:** No. The Objection Proof Chrome extension and mobile app are separate products and are not part of this solution.
- **External endpoints the package calls (outbound):**
  - `https://app.objectionproof.ai/api/call-lead`, `/api/queue-call`, `/api/integrations/salesforce/register`: the Objection Proof platform (Next.js on Vercel, Supabase Postgres)
  - The n8n scoring webhook: Objection Proof's self-hosted n8n instance, with the URL set by the admin in the `objproof_namedcred` Named Credential
- **Inbound entry points:**
  - `PATCH /services/apexrest/objectionproof/v1/task-callback/{token}`: on the customer's Force.com Site (guest user), authorized by a single-use 128-bit token
  - `POST /services/apexrest/objectionproof/v1/call-activity` and `POST /v1/api-key`: OAuth 2.0 client credentials through the packaged External Client App, running as a dedicated integration user
- **Authentication to external services:** the customer's Objection Proof API key, stored in a protected custom setting and sent over TLS through Named Credentials. The key can be rotated by Objection Proof through the OAuth-protected `/v1/api-key` endpoint, and only with proof of the current key.
- **Data sent outside Salesforce:** prospect contact details (name, phone, email, address), the call recording URL, and Task/owner names and IDs. No Salesforce credentials or session IDs are sent. See `architecture.md` §6.
- **Data stored outside Salesforce:** call recordings, transcripts and scores in the Objection Proof platform. Retention: **[YOU]**
- **Encryption:** TLS 1.2+ in transit on every connection; the platform database is encrypted at rest (Supabase)
- **Compliance certifications:** **[YOU: e.g. none / SOC 2 in progress]**

### Documents to upload (all in `submission/`)
| Wizard field | File |
|---|---|
| Architecture / data flow | `architecture.pdf` |
| Security controls | `security.pdf` |
| False positives | `false-positives.pdf` |
| Usage / admin guide | `install-guide.pdf` (README) |
| Code Analyzer report | `code-analyzer-1.13.0.html` |
| DAST report(s) | `zap-active-endpoints.pdf`, `zap-baseline-platform.html`, plus `dast.pdf` (the runbook, including the CDN and CSP notes) |
| Checkmarx | **[YOU: run it from the Partner Security Portal on 1.13.0 and download the report]** |

### Test environments
- **Salesforce test org:** use a **Developer Edition org, which doesn't expire**. Scratch orgs expire in 3 to 30 days and the review can take weeks. **[YOU: sign up at developer.salesforce.com/signup]**, then tell me the username and I'll set it up: install 1.13.0, activate the Site, create and connect the integration user, and add sample data.
- **Platform test account:** a test Objection Proof login and API key for reviewers (for example, test client 6): **[YOU: create a reviewer user]**
- **Walkthrough for reviewers:** `install-guide.pdf` (Installation steps 1–6) plus the end-to-end test in the README

### Payment
- Free listing: $0. If the listing is Paid: $999 per attempt.
