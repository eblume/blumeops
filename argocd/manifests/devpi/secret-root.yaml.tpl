# Template for devpi root password secret
# Create the secret before deploying:
#   kubectl create namespace devpi
#   op inject -i argocd/manifests/devpi/secret-root.yaml.tpl | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: devpi-root
  namespace: devpi
type: Opaque
stringData:
  password: "{{ op://vg6xf6vvfmoh5hqjjhlhbeoaie/kyhzfifryqnuk7jeyibmmjvxxm/root password }}"
