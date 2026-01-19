# Template for eblume superuser password
# Apply with: op inject -i secret-eblume.yaml.tpl | kubectl apply -f -
#
# Uses the same 1Password item as the brew PostgreSQL setup on indri
apiVersion: v1
kind: Secret
metadata:
  name: blumeops-pg-eblume
  namespace: databases
type: kubernetes.io/basic-auth
stringData:
  username: eblume
  password: {{ op://vg6xf6vvfmoh5hqjjhlhbeoaie/guxu3j7ajhjyey6xxl2ovsl2ui/password }}
