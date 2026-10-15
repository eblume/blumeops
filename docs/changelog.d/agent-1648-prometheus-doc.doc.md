Docs: refresh the Prometheus service card — fix the manifest path
(prometheus → prometheus-ringtail), the PVC size (50Gi → 20Gi), the scrape
target table (now 9 jobs; the tailscale CNPG hostname and the dropped
kube-state-metrics entry are gone), add the alloy-ringtail remote-write
source, and add forgejo to the textfile metrics list. Last-reviewed stamp
moved to 2026-10-15.
