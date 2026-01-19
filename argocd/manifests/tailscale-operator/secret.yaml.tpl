# Tailscale Operator OAuth Secret
# This template is processed by `op inject` to resolve 1Password references.
#
# Usage:
#   op inject -i secret.yaml.tpl | kubectl apply -f -
#
apiVersion: v1
kind: Secret
metadata:
  name: operator-oauth
  namespace: tailscale
stringData:
  client_id: "{{ op://vg6xf6vvfmoh5hqjjhlhbeoaie/2it22lavwgbxdskoaxanej354q/client-id }}"
  client_secret: "{{ op://vg6xf6vvfmoh5hqjjhlhbeoaie/2it22lavwgbxdskoaxanej354q/client-secret }}"
