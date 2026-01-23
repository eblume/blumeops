# TeslaMate database password secret
#
# Apply with: op inject -i argocd/manifests/teslamate/secret-db.yaml.tpl | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: teslamate-db
  namespace: teslamate
type: Opaque
stringData:
  password: {{ op://blumeops/TeslaMate/db_password }}
