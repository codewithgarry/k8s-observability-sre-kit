# SLO: podinfo availability

| Field | Value |
|---|---|
| Service | `podinfo` (namespace `sre-demo`) |
| SLI | Share of HTTP requests that do **not** return a 5xx status |
| SLO target | **99.5%** over a rolling **30 days** |
| Error budget | 0.5% of requests ≈ **3h 36m** of full outage per 30 days |
| Data source | `http_request_duration_seconds_count` scraped by Prometheus |
| Owner | Platform team |

## SLI definition

```promql
# Error ratio over a window W
sum(rate(http_request_duration_seconds_count{job="podinfo", namespace="sre-demo", status=~"5.."}[W]))
/
sum(rate(http_request_duration_seconds_count{job="podinfo", namespace="sre-demo"}[W]))
```

4xx responses are excluded, because they are client errors and do not mean the service is unhealthy.

## Why 99.5%?

- The service has no paying users and runs on a small cluster. 99.9% would leave only 43 minutes of budget a month, less than a single node upgrade can take.
- 99.5% still catches serious regressions. A full outage pages within about 5 minutes (see the detection table below).

## Alerting: multiwindow, multi-burn-rate

**Burn rate** is how fast the budget is being spent compared with the sustainable pace. A burn rate of **1** uses exactly the whole budget in 30 days.

| Alert | Burn rate | Long window | Short window | Budget spent before alert | Action |
|---|---|---|---|---|---|
| `PodinfoErrorBudgetBurnFast` | 14.4× | 1h | 5m | 2% | **Page** on-call |
| `PodinfoErrorBudgetBurnFast` | 6× | 6h | 30m | 5% | **Page** on-call |
| `PodinfoErrorBudgetBurnSlow` | 3× | 1d | 2h | 10% | Ticket |
| `PodinfoErrorBudgetBurnSlow` | 1× | 3d | 6h | 10% | Ticket |

- The **long window** makes sure the problem is significant.
- The **short window** makes the alert resolve quickly once the problem is fixed, instead of firing for another hour.

### How fast does it page?

For the 14.4× / 1h rule, detection time ≈ 14.4 ÷ burn rate × 60 minutes:

| Error ratio | Burn rate | Time to page |
|---|---|---|
| 100% (full outage) | 200× | ~5 minutes (window math plus the `for: 2m` delay) |
| 50% | 100× | ~9 minutes |
| 18% | 36× | ~24 minutes |
| 10% | 20× | ~43 minutes |
| 5% | 10× | no fast page. The 6× / 6h rule pages after about 3.6 hours |

This is the deliberate trade-off: the long window prevents pages on short blips but delays pages for moderate failures. Cause-based alerts, such as mass OOMKills on an SLO-backed service, cover that gap. See the [sample postmortem](../postmortems/2026-03-14-podinfo-5xx-after-config-rollout.md).

## Error budget policy

| Budget remaining | Policy |
|---|---|
| > 50% | Normal releases. Experiments allowed. |
| 25% to 50% | Releases continue. Reliability work gets priority in planning. |
| 0% to 25% | Only fixes and reliability changes ship. A postmortem is required for each incident. |
| < 0% (SLO breached) | Feature freeze until the budget recovers. The team lead signs off on exceptions. |

## Review

Review this SLO quarterly. If the budget is never touched, the target may be too loose. If it is always exhausted, either the service or the target needs work.
