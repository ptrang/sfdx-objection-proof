#!/usr/bin/env bash
# Run an OWASP ZAP automation plan headlessly.
#   scripts/dast/run-zap.sh baseline                         # passive, production-safe
#   PLATFORM_URL=https://<preview>.vercel.app API_KEY=<inactive client key> \
#     VERCEL_BYPASS=<bypass secret> scripts/dast/run-zap.sh active   # attacks 2 endpoints on a preview
set -euo pipefail

PLAN="${1:?usage: run-zap.sh baseline|active}"
ZAP="${ZAP_HOME:-$HOME/tools/ZAP_2.17.0}/zap.sh"
HERE="$(cd "$(dirname "$0")" && pwd)"

export PLATFORM_URL="${PLATFORM_URL:-https://app.objectionproof.ai}"
export REPORT_DIR="${REPORT_DIR:-$HERE/reports/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$REPORT_DIR"

if [[ "$PLAN" == "active" ]]; then
  : "${API_KEY:?set API_KEY to an INACTIVE test client's key}"
  : "${VERCEL_BYPASS:?set VERCEL_BYPASS to the preview's protection bypass secret}"
  if [[ "$PLATFORM_URL" == *"app.objectionproof.ai"* ]]; then
    echo "Refusing to run an active scan against production ($PLATFORM_URL)." >&2
    exit 1
  fi
fi

"$ZAP" -cmd -autorun "$HERE/$PLAN.yaml"
echo "Reports: $REPORT_DIR"
