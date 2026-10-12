#!/usr/bin/env bash
# Game day: sends traffic to podinfo where a share of requests return HTTP 500.
# Watch the "SLO · podinfo availability" dashboard and the PodinfoErrorBudgetBurnFast alert.
# Usage: ./scripts/burn-error-budget.sh [error-percent]   (default 20)
set -euo pipefail
ERROR_PCT=${1:-20}

kubectl -n sre-demo run error-generator --rm -it --restart=Never --image=busybox:1.36 -- \
  /bin/sh -c "
    i=0
    while true; do
      i=\$((i + 1))
      if [ \$((i % 100)) -lt $ERROR_PCT ]; then
        wget -q -O- http://podinfo:9898/status/500 >/dev/null 2>&1 || true
      else
        wget -q -O- http://podinfo:9898/ >/dev/null 2>&1 || true
      fi
    done"
