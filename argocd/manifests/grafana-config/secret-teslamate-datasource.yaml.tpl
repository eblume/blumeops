# TeslaMate PostgreSQL datasource password for Grafana
# Apply with: op inject -i argocd/manifests/grafana-config/secret-teslamate-datasource.yaml.tpl | kubectl apply -f -
#
# This secret is mounted as environment variables in Grafana
# The password is referenced in values.yaml datasource config as $TESLAMATE_DB_PASSWORD
apiVersion: v1
kind: Secret
metadata:
  name: grafana-teslamate-datasource
  namespace: monitoring
type: Opaque
stringData:
  TESLAMATE_DB_PASSWORD: {{ op://blumeops/TeslaMate/db_password }}
