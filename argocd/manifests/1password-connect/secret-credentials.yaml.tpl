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
#    - credentials-base64: base64-encoded contents of 1password-credentials.json
#    - token: the access token
#
#    To add credentials-base64 to existing item:
#      CREDS=$(op item get "1Password Connect" --vault blumeops --format json | \
#        jq -r '.fields[] | select(.label == "credentials-file") | .value' | base64)
#      op item edit "1Password Connect" --vault blumeops "credentials-base64=$CREDS"
#
# Usage:
#   kubectl --context=minikube-indri create namespace 1password
#   op inject -i argocd/manifests/1password-connect/secret-credentials.yaml.tpl | \
#     kubectl --context=minikube-indri apply -f -
#
apiVersion: v1
kind: Secret
metadata:
  name: op-credentials
  namespace: 1password
type: Opaque
stringData:
  # OP_SESSION env var expects base64-encoded credentials
  1password-credentials.json: "{{ op://blumeops/1Password Connect/credentials-base64 }}"
---
apiVersion: v1
kind: Secret
metadata:
  name: onepassword-token
  namespace: 1password
type: Opaque
stringData:
  token: "{{ op://blumeops/1Password Connect/token }}"
