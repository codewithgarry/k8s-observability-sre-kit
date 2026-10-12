# Runbooks

Every alert in this repo links to a runbook through its `runbook_url` annotation.

| Runbook | Alerts | Typical severity |
|---|---|---|
| [Pod CrashLoopBackOff / OOMKilled](pod-crashloopbackoff.md) | `PodCrashLooping`, `ContainerOOMKilled`, `DeploymentReplicasUnavailable`, `NodeMemoryHigh` | warning |
| [Node disk pressure](node-disk-pressure.md) | `NodeDiskWillFillIn24h`, `NodeDiskAlmostFull` | warning / critical |
| [SLO error budget burn](slo-error-budget-burn.md) | `PodinfoErrorBudgetBurnFast`, `PodinfoErrorBudgetBurnSlow` | critical / warning |

## How the runbooks are written

1. **Impact first.** What users experience, so on-call can judge urgency in seconds.
2. **Copy-paste triage.** Commands that work as written, with placeholders in `<angle brackets>`.
3. **Decision points.** "If you see X, go to Y" instead of long prose.
4. **Mitigate before you fix.** Restore service first. Find the root cause afterwards.
5. **Escalation and verification.** Who to call, and how to confirm the alert is truly resolved.
