# ArgoCD credential template for forge SSH access
# This is a repo-creds (credential template) that matches ALL repos under eblume/
#
# IMPORTANT: Use ?ssh-format=openssh to get OpenSSH format (required by ArgoCD)
#
# The SSH key must be added to the Forgejo user's SSH keys (not as a deploy key)
# so it has access to all repos owned by that user.
#
# Create the secret with:
#
#   PRIV_KEY=$(op read "op://vg6xf6vvfmoh5hqjjhlhbeoaie/csjncynh6htjvnh2l2da65y32q/private key?ssh-format=openssh")$'\n' && \
#   kubectl create secret generic repo-creds-forge -n argocd \
#     --from-literal=type=git \
#     --from-literal=url='ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/' \
#     --from-literal=insecure=true \
#     --from-literal=sshPrivateKey="$PRIV_KEY" && \
#   kubectl label secret repo-creds-forge -n argocd argocd.argoproj.io/secret-type=repo-creds
#
apiVersion: v1
kind: Secret
metadata:
  name: repo-creds-forge
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/
  insecure: "true"
  sshPrivateKey: |
    # Key from 1Password: op://vg6xf6vvfmoh5hqjjhlhbeoaie/csjncynh6htjvnh2l2da65y32q/private key
