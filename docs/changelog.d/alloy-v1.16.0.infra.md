Upgrade Grafana Alloy v1.14.0 → v1.16.0 across all four service deployments
(alloy-k8s, alloy-ringtail, alloy-tracing-ringtail on k8s; alloy native on
indri). Pulls in stable database observability (v1.15) and the OTel Collector
v0.147.0 bump. Container build also migrated from Dockerfile to native Dagger
`container.py` per the build-container-image migration playbook.
