# DAST (Dynamic Scan) Runbook — Objection Proof

The security review requires a DAST report for every external endpoint the package talks to. We use **OWASP ZAP 2.17.0**, run headlessly from the automation plans in [`scripts/dast/`](../../scripts/dast).

## Scope

| Endpoint | Scanned how |
|---|---|
| `https://app.objectionproof.ai/api/call-lead`, `/api/queue-call` | Passive baseline on production; full active scan on a staging or preview deployment |
| n8n scoring webhook (self-hosted; URL in `objproof_namedcred`) | Full active scan on a staging copy of the webhook |
| `{site}/services/apexrest/objectionproof/v1/task-callback/{token}` | Not scanned: it is hosted on Salesforce infrastructure. It is covered by the architecture review and by tests (see [`false-positives.md`](false-positives.md)). |

**Never run the active plan against production.** It sends thousands of attack requests. `run-zap.sh` refuses to run it against `app.objectionproof.ai`.

## Setup (once)

ZAP's Homebrew cask was disabled on 2026-09-01 (it fails Gatekeeper), so use the official cross-platform build. It needs Java 17 or later.

```bash
mkdir -p ~/tools && cd ~/tools
curl -LO https://github.com/zaproxy/zaproxy/releases/download/v2.17.0/ZAP_2.17.0_Crossplatform.zip
shasum -a 256 ZAP_2.17.0_Crossplatform.zip   # must equal 94c8f767b1c2e94f0db66b3ae56514d5e3f5a728ee1b6c798e0c8fe2d61fbff0
unzip -q ZAP_2.17.0_Crossplatform.zip && rm ZAP_2.17.0_Crossplatform.zip
```

## Run

```bash
# Passive baseline (production-safe: invalid API key, no attacks)
scripts/dast/run-zap.sh baseline

# Full active scan (staging only)
PLATFORM_URL=https://<preview>.vercel.app \
N8N_WEBHOOK_URL=https://<staging-n8n>/webhook/<id> \
API_KEY=<staging test key> \
scripts/dast/run-zap.sh active
```

Reports are written to `scripts/dast/reports/<timestamp>/` (gitignored). Upload the active-scan HTML or PDF report to the security review, together with a short note on each remaining finding.

## Results

### 2026-09-23: passive baseline, production (`app.objectionproof.ai`)

No High findings.

| Risk | Finding | Fix |
|---|---|---|
| Medium | Missing anti-clickjacking header | `X-Frame-Options: SAMEORIGIN` plus CSP `frame-ancestors 'self'` |
| Medium | Cross-domain misconfiguration (`Access-Control-Allow-Origin: *`) | The `*` comes from page responses; restrict pages to the app origin. `/api` routes send no `Access-Control-Allow-Origin` (verified); leave them unchanged, since the Chrome extension calls `/api/queue-call` cross-origin. |
| Medium | Content Security Policy not set | Add a CSP, starting in `Content-Security-Policy-Report-Only` mode |
| Low | `X-Content-Type-Options` missing | Send `X-Content-Type-Options: nosniff` |
| Info | Cache-control directives, suspicious comments in JS bundles, "retrieved from cache" on `/api` | Review: API responses should send `Cache-Control: no-store` |

The same scan also turned up a code issue: on a malformed JSON body, `POST /api/call-lead` writes the caller's `api_key` and the raw body to the console log and to its failure log. It should log neither.

### Still to do
- Deploy the header fix (platform branch `feat/security-headers`) and the logging fix (`fix/call-lead-no-secret-logging`), then re-run the baseline
- Active scan against a staging platform deployment and a staging n8n webhook
