# Postmortem: podinfo returned 5xx for 53 minutes after a config rollout

> **Sample postmortem.** This incident is fictional. The numbers are consistent with the SLO and alert rules in this repo, and the error pattern can be simulated with [`scripts/burn-error-budget.sh`](../scripts/burn-error-budget.sh). It shows the structure and level of detail I aim for in real postmortems.

| | |
|---|---|
| **Date** | 2026-03-14 |
| **Authors** | Girish Sharma |
| **Status** | Final |
| **Severity** | SEV2 |
| **Duration** | 53 minutes of user impact (09:12 to 10:05 UTC) |
| **Error budget consumed** | ~3.5% of the 30-day budget |

## Summary

A configuration change lowered podinfo's memory limit from 128 Mi to 48 Mi. Under normal morning traffic, pods were OOMKilled every few minutes. While pods restarted, the remaining replicas were overloaded and about 18% of requests returned HTTP 503. Rolling back the change through Git restored service.

## Impact

- About **18% of requests failed** at the peak. The average error ratio was about 14% over 53 minutes.
- No data loss. podinfo is stateless.
- SLO: the fast-burn alert fired at a peak burn rate of **36×** (18% errors against a 0.5% budget). About **3.5% of the monthly error budget** was consumed: 53 minutes × 14% average errors ≈ 7.4 minutes of full outage, out of a 216-minute budget.
- The total is small, but the rate is what matters. At 36×, the whole 30-day budget would have been gone in **under a day**.

## Timeline (UTC)

| Time | Event |
|---|---|
| 09:05 | PR merged that tuned resource values in `values.yaml`, including memory limit `128Mi → 48Mi` |
| 09:08 | Argo CD synced. Rolling update completed with no errors |
| 09:12 | Morning traffic rises. First `OOMKilled` restarts. Error ratio climbs to 6% |
| 09:16 | `ContainerOOMKilled` (warning) posts to the ticket channel. Nobody is watching it |
| 09:20 | Error ratio reaches 18% (burn rate 36×) |
| 09:37 | `PodinfoErrorBudgetBurnFast` (critical) pages on-call |
| 09:40 | On-call acknowledges and opens the SLO dashboard: burn rate 36×, all pods affected |
| 09:45 | Correlates the start time with the 09:08 sync. `kubectl describe pod` shows `Last State: OOMKilled` |
| 09:49 | Attempts `kubectl set resources` to raise the limit. **Argo CD self-heal reverts it within a minute** |
| 09:56 | Opens a revert PR. Second engineer approves |
| 09:59 | Revert merged. Argo CD syncs the previous values |
| 10:05 | All pods running with 128 Mi. Error ratio back below 0.1% |
| 10:12 | Fast-burn alert resolves. Incident closed |

## Root cause

The memory limit was set below the service's real working set under load.

1. **Why did pods crash?** They exceeded the new 48 Mi limit and were OOMKilled.
2. **Why was the limit 48 Mi?** It was based on a `kubectl top` reading taken off-peak, when usage was about 35 Mi.
3. **Why wasn't peak usage considered?** There was no documented process for sizing resources, and the PR template did not ask for evidence.
4. **Why didn't CI catch it?** CI validates syntax and schemas only. Nothing compares limits with observed usage.
5. **Why did the rollout look healthy?** Pods start and pass readiness at low memory. The problem only appears under load, after the rollout finished.

## Trigger

Normal morning traffic growth at 09:12, about 4 minutes after the change was synced.

## Detection

- Monitoring detected the issue **before any user report**, but slowly.
- Time to detect, from first impact to page: **25 minutes.**
- This matches the alert design. With a 1-hour long window, detection time ≈ threshold ÷ burn rate × window = 14.4 ÷ 36 × 60 min ≈ **24 minutes**. The 1h window protects against paging on short blips, but it delays pages for sharp, sustained failures.
- The OOMKilled warning fired 21 minutes earlier, but it went to the ticket channel.

## Resolution

Reverting the commit in Git. Argo CD synced the previous memory limit, and pods stopped being killed.

## What went well

- The SLO alert paged with the right severity and linked straight to the runbook.
- The dashboard made the "all pods, started at a deploy" pattern obvious within minutes.
- The revert-PR path was quick once chosen.

## What went wrong

- 7 minutes were lost trying a manual `kubectl` fix, which Argo CD self-heal reverted. The runbook mentioned GitOps, but only in a note.
- The resource change was bundled with unrelated tuning, which made the PR harder to review.
- No canary or progressive rollout, so 100% of pods got the bad limit at once.

## Where we got lucky

- It happened during working hours with two engineers available to approve the revert.
- Traffic was moderate. At peak evening load the error ratio would likely have been much higher.

## Action items

| # | Action | Type | Owner | Priority | Status |
|---|---|---|---|---|---|
| 1 | Move "with GitOps, revert in Git" to step 1 of the mitigation section in all runbooks | mitigate | Girish | P1 | Done |
| 2 | Add a CI check that fails if a memory limit is below the 7-day p99 working set from Prometheus | prevent | Platform | P1 | Open |
| 3 | Route `ContainerOOMKilled` for SLO-backed services to the pager when more than 2 pods are affected | detect | Platform | P2 | Open |
| 4 | Add a "resource change evidence" checklist item to the PR template | process | Platform | P2 | Done |
| 5 | Evaluate Argo Rollouts canary for the demo service | prevent | Platform | P3 | Open |

## Lessons learned

- **Size resources from peak data, not a snapshot.** `kubectl top` is a single point in time. Use the p99 of `container_memory_working_set_bytes` over days.
- **In GitOps, the fastest safe fix is a revert in Git.** Manual changes fight the reconciler and waste time during an incident.
- **SLO-based paging is reliable but not instant.** It paged on real user impact, not on every restart. For sharp failures, a cause-based signal such as mass OOMKills on an SLO-backed service is the faster trigger. Action item 3 adds it.
