# TeslaMate encryption key secret
# This key encrypts Tesla API tokens at rest in the database
#
# Apply with: op inject -i argocd/manifests/teslamate/secret-encryption-key.yaml.tpl | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: teslamate-encryption
  namespace: teslamate
type: Opaque
stringData:
  key: {{ op://blumeops/TeslaMate/api_enc_key }}
