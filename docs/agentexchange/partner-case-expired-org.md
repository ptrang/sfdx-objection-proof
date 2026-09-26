# Partner Support case: expired trial org that holds our listing

**Where:** https://partners.salesforce.com → **Help** (the "?" icon) → **Log a Case**. Choose the AgentExchange / Partner Operations topic, or "Partner Business Org" if it is offered.

**Subject:** Listing org shows "Trial Expired". Please restore it or provision a Partner Business Org and move our listing

**Description (paste, filling the two brackets):**

> Hello,
>
> We are Disruptor Solutions Incorporated, an ISV partner. We created an AgentExchange listing for our managed package, but the org we used for it now shows "Your Salesforce trial has ended" at login. It is still inside the 30-day window.
>
> - Expired org username: [USERNAME YOU LOGGED IN WITH]
> - Expired org ID (if known): [ORG ID]
> - Partner Community user: patrick@closemoresales.com
> - Product: Objection Proof AI (AI sales coaching and AI calling for Sales Cloud)
> - Package: "Objection Proof", second-generation managed package, namespace `objectionproof`, package ID 0HogL0000000QKHSA2
> - Dev Hub (owns the package): org ID 00DgL000006LHGvUAO
> - Current released version: 1.13.0 (04tgL000000W6zxQAC)
>
> Please:
> 1. Stop the expired org from being deleted. Either restore it, or convert or replace it with a Partner Business Org (PBO) for our partner account, including the License Management App (LMA).
> 2. Keep or move our existing AgentExchange listing so it is tied to our partner account and that PBO.
> 3. Confirm that our Dev Hub is (or can be) connected in the Partner Console, so we can link version 1.13.0 to the listing and start the security review.
>
> Our package is free, and it is included with our $15,000-per-year Objection Proof AI subscription, which we bill directly. Please also advise whether the listing should be Free or Paid under ISVforce.
>
> Thank you,
> Patrick Trang

**Find the username / org ID before sending:**
- Check your email for the original "Welcome to Salesforce" or trial sign-up message; it contains the username.
- If you can still reach the Setup screen from the expired org before the lock, the org ID is under **Setup → Company Information**.

**If they provision a new PBO instead of restoring:** log in to it, install the LMA if it isn't there, then in the Partner Console connect the Dev Hub (00DgL000006LHGv) and re-link the listing.
