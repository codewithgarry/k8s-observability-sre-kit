# Runbook: Node disk pressure

| | |
|---|---|
| **Alerts** | `NodeDiskWillFillIn24h` (warning), `NodeDiskAlmostFull` (critical) |
| **Impact** | At about 10-15% free, kubelet sets `DiskPressure`, **evicts pods** and blocks new ones. At 0%, container runtime and logging fail. |

## 1. Triage

```bash
NODE=<node-name>   # the alert's "instance" label maps to this node

kubectl describe node $NODE | grep -A5 Conditions        # DiskPressure True?
kubectl get pods -A --field-selector spec.nodeName=$NODE -o wide | grep -i evicted
```

How fast is it filling? In Prometheus:

```promql
deriv(node_filesystem_avail_bytes{instance="<instance>", mountpoint="/"}[1h]) * 3600   # bytes per hour (negative = filling)
```

- **Losing GBs per hour:** something is writing aggressively. Treat as urgent.
- **Slow steady decline:** usually images or logs accumulating. Plan a cleanup.

## 2. Find what is using space

```bash
kubectl debug node/$NODE -it --image=busybox:1.36 -- chroot /host sh

# Inside the node:
df -h /
du -xh --max-depth=1 /var/lib 2>/dev/null | sort -h | tail
du -xh --max-depth=1 /var/log 2>/dev/null | sort -h | tail
crictl images | wc -l
```

| Biggest consumer | Typical cause | Fix |
|---|---|---|
| `/var/lib/containerd` | Many old or unused images | `crictl rmi --prune` |
| `/var/log/pods` | A pod logging excessively | Find it, reduce log level or fix the loop |
| `/var/lib/kubelet/pods/*/volumes` | `emptyDir` filled by an app | Set `sizeLimit` on the `emptyDir`, fix the app |
| `/var/log/journal` | Journald without limits | `journalctl --vacuum-size=500M` |

## 3. Mitigate

```bash
# Stop new pods landing on the node while you clean up
kubectl cordon $NODE

# Inside the node (chroot /host):
crictl rmi --prune                       # remove unused images
journalctl --vacuum-size=500M            # trim system journal
```

If a single pod is the cause:

```bash
kubectl -n <ns> delete pod <noisy-pod>   # frees its emptyDir and logs; it is rescheduled
```

If the disk is simply too small for the workload: drain the node and resize the disk or replace the node with a larger one.

```bash
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data
```

## 4. Verify

```bash
kubectl describe node $NODE | grep DiskPressure    # False
kubectl uncordon $NODE
```

## 5. Prevent recurrence

- Set kubelet image garbage collection thresholds (`imageGCHighThresholdPercent`, `imageGCLowThresholdPercent`).
- Configure container log rotation (`containerLogMaxSize`, `containerLogMaxFiles`).
- Add `sizeLimit` to every `emptyDir` and `ephemeral-storage` requests and limits to workloads.
