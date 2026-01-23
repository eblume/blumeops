# Template for TeslaMate database user password
# Apply with: op inject -i argocd/manifests/databases/secret-teslamate.yaml.tpl | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: blumeops-pg-teslamate
  namespace: databases
type: kubernetes.io/basic-auth
stringData:
  username: teslamate
  password: {{ op://blumeops/TeslaMate/db_password }}
