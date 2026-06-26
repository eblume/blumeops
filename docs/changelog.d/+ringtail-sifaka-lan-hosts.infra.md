Pinned `sifaka` to its LAN IP (`192.168.1.203`) in ringtail's `/etc/hosts` via
`networking.hosts`, so NFS mounts resolve over the LAN instead of tailscale
MagicDNS. On 2026-06-26 sifaka's tailscale node key expired; MagicDNS kept
resolving `sifaka` to the now-dead node and every NFS mount on ringtail hung
(kiwix, transmission, immich, paperless, etc.). The LAN path is authoritative
(`/etc/hosts` beats MagicDNS), keeps NFS traffic off the tailnet, and is immune
to tailscale node-key churn — implementing the design the immich `pv-nfs.yaml`
comment always described. sifaka's NFS export already permits `192.168.1.0/24`.
Also disabled key expiry on sifaka's tailscale node so it stops expiring.
