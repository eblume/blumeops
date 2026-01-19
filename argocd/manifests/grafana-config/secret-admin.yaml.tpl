# Grafana admin password secret
#
# Apply with: op inject -i secret-admin.yaml.tpl | kubectl apply -f -
#
# 1Password item: blumeops vault (vg6xf6vvfmoh5hqjjhlhbeoaie)
# Item ID: oxkcr3xtxnewy7noep2izvyr6y
# Field: password
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin
  namespace: monitoring
type: Opaque
stringData:
  admin-user: admin
  admin-password: {{ op://vg6xf6vvfmoh5hqjjhlhbeoaie/oxkcr3xtxnewy7noep2izvyr6y/password }}
