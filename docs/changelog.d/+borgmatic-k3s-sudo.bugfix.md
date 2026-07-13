Restored the nightly indri borgmatic run, which had aborted since 2026-07-10.
The multi-user hardening that locked `/etc/rancher/k3s/k3s.yaml` to `0600 root`
on ringtail also locked out `eblume`, the user borgmatic's `before: configuration`
k8s-dump hooks SSH in as to snapshot mealie/shower/navidrome — a non-zero hook
exit aborts the whole run, so nothing landed. The hooks now reach the cluster
via `sudo k3s kubectl`, keeping the kubeconfig locked away from the restricted
web-agent user.
