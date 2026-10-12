# Runbook: SLO error budget burn

| | |
|---|---|
| **Alerts** | `PodinfoErrorBudgetBurnFast` (critical, pages), `PodinfoErrorBudgetBurnSlow` (warning, ticket) |
| **SLO** | 99.5% of requests non-5xx over 30 days. See [the SLO doc](../slo/podinfo-availability.md). |
| **Impact** | Users are getting errors right now. Fast burn means the whole monthly budget will be gone in under 5 days at the current rate. |

## 1. Acknowledge and assess (first 5 minutes)

1. Acknowledge the page and say in the incident channel that you are investigating.
2. Open the **"SLO · podinfo availability"** Grafana dashboard. Answer these three questions:

| Question | Where to look |
|---|---|
| How bad is it? | *Burn rate (1h)* stat and *Requests by status* panel |
| Since when? | Burn rate graph, plus the alert annotation on the timeline |
| Is it getting worse? | 5m burn rate rising vs. falling |

**Declare an incident** if the burn rate is above 14.4 for more than 15 minutes or the error ratio is above 20%.

## 2. Find the trigger

Most incidents are caused by a change. Check changes first.

```bash
# Recent rollouts
kubectl -n sre-demo rollout history deployment/podinfo
kubectl -n sre-demo get events --sort-by=.lastTimestamp | tail -20

# GitOps: recent commits that touched the service
git log --since="3 hours ago" --oneline -- charts/ gitops/
```

```promql
# Errors by pod: one bad pod or all of them?
sum by (pod) (rate(http_request_duration_seconds_count{namespace="sre-demo", status=~"5.."}[5m]))

# Errors by path: one endpoint or everything? (needs a path label on the metric)
sum by (path) (rate(http_request_duration_seconds_count{namespace="sre-demo", status=~"5.."}[5m]))
```

| Pattern | Likely cause | Go to |
|---|---|---|
| Started at a deploy | Bad release or config | Roll back |
| One pod only | Bad node or stuck pod | Delete the pod, check its node |
| All pods, no deploy | Dependency or traffic spike | Check dependency dashboards and request rate |
| One endpoint only | Code path bug | Roll back or feature-flag it off |

## 3. Mitigate (restore service first)

```bash
# Bad release -> roll back (with GitOps: git revert the commit and let Argo CD sync)
kubectl -n sre-demo rollout undo deployment/podinfo

# Single bad pod -> replace it
kubectl -n sre-demo delete pod <pod>

# Overload -> add capacity
kubectl -n sre-demo scale deployment/podinfo --replicas=6
```

## 4. Verify

- The 5m burn rate drops below 1 within minutes of the fix.
- `PodinfoErrorBudgetBurnFast` resolves. The short window lets it clear quickly.
- Note the **budget consumed** from the *Error budget remaining* panel for the postmortem.

## 5. Follow up

- Fast burn or more than 5% of budget consumed: **postmortem required.** Use the [template](../postmortems/TEMPLATE.md).
- Apply the [error budget policy](../slo/podinfo-availability.md#error-budget-policy) for the remaining budget.

### Slow burn (ticket)

No need to act at night. During working hours, look for a slowly growing error source, such as a flaky dependency or a single noisy endpoint, and open a fix ticket.
