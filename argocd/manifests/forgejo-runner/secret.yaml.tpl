# Forgejo Runner Environment Secret
# This template is processed by `op inject` to resolve 1Password references.
#
# Usage:
#   op inject -i secret.yaml.tpl | kubectl --context=minikube-indri apply -f -
#
apiVersion: v1
kind: Secret
metadata:
  name: forgejo-runner-env
  namespace: forgejo-runner
type: Opaque
stringData:
  FORGEJO_URL: "https://forge.ops.eblu.me"
  RUNNER_NAME: "k8s-runner"
  RUNNER_LABELS: "k8s:docker://registry.ops.eblu.me/blumeops/forgejo-runner:v2.1.3"
  RUNNER_TOKEN: "{{ op://vg6xf6vvfmoh5hqjjhlhbeoaie/w3663ffnvkewbftncqxtcpeavy/runner_reg }}"
