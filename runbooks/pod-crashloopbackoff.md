# Runbook: Pod CrashLoopBackOff / OOMKilled

| | |
|---|---|
| **Alerts** | `PodCrashLooping`, `ContainerOOMKilled`, `DeploymentReplicasUnavailable` |
| **Severity** | warning, page if user-facing SLO alerts fire too |
| **Impact** | Reduced capacity. If every replica is affected, the service is down. |

## 1. Triage (first 5 minutes)

```bash
NS=<namespace>; POD=<pod>

# How widespread is it? One pod, one deployment, or the whole node?
kubectl -n $NS get pods -o wide | grep -v Running
kubectl get pods -A --field-selector=status.phase!=Running | head -30

# Did something just change?
kubectl -n $NS rollout history deployment/<deployment>
kubectl -n $NS get events --sort-by=.lastTimestamp | tail -20
```

- **Started right after a rollout?** Go straight to [Mitigation: roll back](#rollback).
- **All pods on one node?** Suspect the node. See [node-disk-pressure.md](node-disk-pressure.md) and check `kubectl describe node`.

## 2. Diagnose

```bash
kubectl -n $NS describe pod $POD | sed -n '/State:/,/Ready:/p'   # exit code + reason
kubectl -n $NS logs $POD --previous --tail=100                   # logs of the crashed container
```

| Last state / exit code | Likely cause | Next step |
|---|---|---|
| `OOMKilled` / 137 | Memory limit too low or a leak | [OOMKilled](#oomkilled) |
| `Error` / 1 | Application error at startup: config, missing secret, dependency down | Read `--previous` logs |
| `Error` / 127 or 126 | Wrong command or entrypoint, missing binary | Check image tag and `command` |
| `Completed` / 0 | Process exits on purpose (wrong workload type) | Should it be a Job? |
| Liveness probe failed in events | Probe too strict or app hanging | Compare probe timings with startup time |
| `CreateContainerConfigError` | Missing ConfigMap or Secret key | `kubectl -n $NS get cm,secret` |

### OOMKilled

```bash
# Memory usage vs limit over the last hour (Prometheus)
max by (pod, container) (container_memory_working_set_bytes{namespace="<ns>", pod=~"<deployment>.*"})
max by (pod, container) (kube_pod_container_resource_limits{namespace="<ns>", resource="memory"})
```

- **Usage climbs steadily until the kill:** probably a leak. Raise the limit temporarily and open a bug.
- **Usage jumps at a load spike:** the limit is too low for peak traffic. Raise it based on the observed p99 plus headroom.
- **Node memory is also high (`NodeMemoryHigh`):** the node is overcommitted. Check requests vs limits across pods on it.

## 3. Mitigate

<a id="rollback"></a>**Bad rollout: roll back first, investigate second.**

```bash
kubectl -n $NS rollout undo deployment/<deployment>
kubectl -n $NS rollout status deployment/<deployment>
```

> With GitOps (Argo CD), revert the commit in Git instead. A manual rollback would be reverted by self-heal.

**Memory limit too low: raise it as a temporary fix.**

```bash
kubectl -n $NS set resources deployment/<deployment> -c <container> --limits=memory=512Mi
```

**Dependency down (database, API):** the crash loop is a symptom. Escalate to the dependency owner and consider scaling the crashing deployment to its minimum to reduce noise.

## 4. Verify

```bash
kubectl -n $NS get pods -w        # restarts stop increasing, pods Ready
```

The alert resolves once no container has been in CrashLoopBackOff for 5 minutes.

## 5. Escalate

- Not mitigated within **30 minutes**, or user-facing SLO alerts are firing: page the service owner.
- Afterwards: if the error budget was affected, write a postmortem using [the template](../postmortems/TEMPLATE.md).
