# ArgoCD repository secret for forge SSH access
#
# IMPORTANT: Use ?ssh-format=openssh to get OpenSSH format (required by ArgoCD)
#
# Create the secret with:
#
#   PRIV_KEY=$(op read "op://vg6xf6vvfmoh5hqjjhlhbeoaie/csjncynh6htjvnh2l2da65y32q/private key?ssh-format=openssh")$'\n' && \
#   kubectl create secret generic repo-forge -n argocd \
#     --from-literal=type=git \
#     --from-literal=url='ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git' \
#     --from-literal=insecure=true \
#     --from-literal=sshPrivateKey="$PRIV_KEY" && \
#   kubectl label secret repo-forge -n argocd argocd.argoproj.io/secret-type=repository
#
apiVersion: v1
kind: Secret
metadata:
  name: repo-forge
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git
  insecure: "true"
  sshPrivateKey: |
    # Key from 1Password: op://vg6xf6vvfmoh5hqjjhlhbeoaie/csjncynh6htjvnh2l2da65y32q/private key
