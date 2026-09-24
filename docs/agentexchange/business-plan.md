# Objection Proof AI — AgentExchange Business Plan (DRAFT)

Draft prepared 2026-09-23 for the Salesforce Business Plan Review. Items marked **[NEEDS INPUT]** must be completed by Steve or Patrick before submission. Everything else is drawn from the product, the codebase and the partner assessment.

---

## 1. Company

| | |
|---|---|
| Legal entity | Disruptor Solutions Incorporated |
| Headquarters | Phoenix, Arizona |
| Employees | 12 |
| Website | https://objectionproof.ai |
| Partner Program status | Partner Community access, Partner Business Org access, listing submitted |
| Team building it | Disruptors / Close More Sales: Steve Trang, Patrick Trang (technical, patrick@closemoresales.com) |

## 2. Solution

**Objection Proof AI** is an AI sales-coaching and AI-calling platform for real estate and B2B sales teams. The **Objection Proof** managed package (2GP, namespace `objectionproof`) brings it natively into Sales Cloud:

1. **AI call scoring.** When a rep's call recording is attached to a Task, the call is scored across 10 coaching metrics plus an overall score. Transcripts and evaluations are written back to the Task and a Call Analysis record.
2. **AI outbound calling.** New Leads, and Leads or Opportunities flagged for follow-up, are called by the Objection Proof AI caller. New and follow-up calls are detected automatically.
3. **AI call logging.** Every AI call is logged back into Salesforce: the prospect is matched (or a Lead is created), and a Task, Call Analysis, outcome and appointment are recorded.

Setup is guided by an in-app Setup tab (permission sets, API key, callback site, integration user).

## 3. Problem and ideal customer

**Problem:** sales managers have no consistent visibility into call quality. Manual call QA doesn't scale. Speed-to-lead and follow-up calls get dropped, and calls made outside the CRM never get logged.

**Ideal customer profile (ICP):**
- Real estate investing, brokerage and home-services sales teams, and SMB and mid-market B2B inside-sales teams
- 5 to 100 reps on Salesforce Sales Cloud
- High inbound lead volume, phone-first selling
- Buyer: VP Sales or Sales Manager (outcome) and RevOps or Salesforce Admin (install and governance)
- **[NEEDS INPUT]**: confirm the top 2 verticals by revenue today

## 4. Market and demand

- Demand is validated by the existing objectionproof.ai SaaS, which has paying customers and is the company's main revenue engine.
- 5 existing Objection Proof customers already run Salesforce but don't use this package yet; they are the first conversion targets.
- 3 beta customers on Salesforce.

## 5. Competition

| Competitor | Their focus | Objection Proof difference |
|---|---|---|
| Gong | Enterprise revenue intelligence | Built for phone-heavy SMB and mid-market teams. It *places* AI calls as well as analyzing them, at a fraction of the price. |
| Chorus (ZoomInfo) | Conversation intelligence, bundled with data | Coaching around a proprietary 10-metric methodology (objection handling, remorse handling, non-needy posture, and more) |
| Revenue.io | Dialer + guidance | An AI caller that does speed-to-lead and follow-ups on its own, logged natively to Salesforce |

## 6. Pricing and packaging

- **Model:** the managed package is **free**; there is no charge for it. It is included with the Objection Proof AI solution, priced at **$15,000 per year**.
- **Free tier:** the package can be installed and configured at no cost. Scoring, AI calling and AI call logging require an active Objection Proof plan.
- **Billing:** billed directly by Objection Proof, as today, through the existing platform billing. Orders are reported to Salesforce through the **Channel Order App (COA)** under the **ISVforce** agreement (15% revenue share; 10% above $20M per year).
- **To confirm with the partner manager:** whether a free package whose value comes from an external paid subscription should be listed as "Free" or "Paid". This affects the revenue share and the $999 security review fee (free listings pay no review fee). Ask when the PBO request is answered.

## 7. Go-to-market

- **Existing base:** convert current Objection Proof customers who run Salesforce first; this is the fastest path to installs and reviews.
- **Brand and content:** the Real Estate Disruptors podcast and training audience, plus webinars showing the AI caller logging into Salesforce live.
- **Listing:** copy written as answers to buyer problems ("How do I get every inbound lead called in 60 seconds and logged in Salesforce?"), because AgentExchange search is intent-based.
- **Agentforce:** **[NEEDS INPUT / roadmap]**: an Agentforce action ("Queue an AI follow-up call", "Score this call") listed alongside the package during the Agentforce launch wave.
- **Sales motion:** founder-led sales and demos. Co-selling with Salesforce AEs becomes a target once ARR from the listing justifies it.
- Dedicated marketing: 1 marketer supports the solution.

## 8. Year-1 targets

| Metric | Target |
|---|---|
| Listing go-live | End of April **[confirm year]** |
| Customers using the package (year 1) | 100 |
| Revenue forecast (year 1) | $1.7M, pre-Salesforce collaboration |

## 9. Security, support and operations

- The security review is being prepared. Code Analyzer is down to 11 findings, all justified, and none High. The architecture, data-flow and DAST documents are in `docs/security-review/`.
- Secrets are stored in protected settings. Inbound calls use a single-use callback token and OAuth client credentials, with least-privilege permission sets.
- **Support:** in-app chat (Intercom) and email, with a same-business-day first response. **[NEEDS INPUT]**: the support email address and hours to publish
- Customer documentation: the installation guide (README) and the in-app Setup tab

## 10. Roadmap (next 2 quarters)

- AgentExchange listing and a released 1.12 version
- Agentforce actions for AI call queueing and scoring **[confirm]**
- Call analytics dashboards and report types in Salesforce **[confirm]**
