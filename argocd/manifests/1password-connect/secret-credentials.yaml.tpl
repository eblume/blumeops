# 1Password Connect bootstrap credentials
#
# This template is processed ONCE manually to bootstrap the system.
# After External Secrets is operational, this could be converted to an
# ExternalSecret for self-management (chicken-and-egg bootstrap).
#
# Prerequisites:
# 1. Create Connect server: op connect server create blumeops --vaults blumeops
# 2. Create token: op connect token create blumeops --server <server-id> --vault blumeops
# 3. Create 1Password item "1Password Connect" in blumeops vault with:
#    - credentials-file: contents of 1password-credentials.json (raw JSON)
#    - token: the access token
#
# Usage:
#   kubectl --context=minikube-indri create namespace 1password
#   op inject -i argocd/manifests/1password-connect/secret-credentials.yaml.tpl | \
#     kubectl --context=minikube-indri apply -f -
#
# Note: chart 2.3.0+ mounts credentials as a file with standard k8s base64.
# Use raw JSON here (not pre-encoded); k8s stringData handles encoding.
#
apiVersion: v1
kind: Secret
metadata:
  name: op-credentials
  namespace: 1password
type: Opaque
stringData:
  1password-credentials.json: "{{ op://blumeops/1Password Connect/credentials-file }}"
---
apiVersion: v1
kind: Secret
metadata:
  name: onepassword-token
  namespace: 1password
type: Opaque
stringData:
  token: "{{ op://blumeops/1Password Connect/token }}"
