The PodNotReady runbook told you to run `kubectl top` — which cannot work on
ringtail, whose k3s runs `--disable=metrics-server`. Step 4 was a guaranteed
dead end, reached exactly when someone is mid-incident chasing a Pending pod.
Replaced with Prometheus queries (every metric verified to exist first), and
noted why they are the better tool anyway: `Pending` is a question about
requests versus allocatable, which utilisation numbers do not answer.
