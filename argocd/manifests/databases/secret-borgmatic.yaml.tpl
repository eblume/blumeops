# Template for borgmatic backup user password
# Apply with: op inject -i secret-borgmatic.yaml.tpl | kubectl apply -f -
#
# Uses the same borgmatic password from 1Password as the brew PostgreSQL setup
apiVersion: v1
kind: Secret
metadata:
  name: blumeops-pg-borgmatic
  namespace: databases
type: kubernetes.io/basic-auth
stringData:
  username: borgmatic
  password: {{ op://vg6xf6vvfmoh5hqjjhlhbeoaie/mw2bv5we7woicjza7hc6s44yvy/db-password }}
