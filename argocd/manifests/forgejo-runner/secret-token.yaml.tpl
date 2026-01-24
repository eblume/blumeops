# Template for op inject
# Usage: op inject -i secret-token.yaml.tpl | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: forgejo-runner-token
  namespace: forgejo-runner
type: Opaque
stringData:
  token: "op://blumeops/w3663ffnvkewbftncqxtcpeavy/runner_reg"
