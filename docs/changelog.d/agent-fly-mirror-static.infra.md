fly.io proxy: build the static forge mirror (staging vhost on
blumeops-proxy.fly.dev — stagit HTML + git dumb HTTP on a Fly volume,
Anubis-fronted, 302 to forge.ops.eblu.me for non-static paths) and
persist the tailscale node key on the volume so reboots reuse the
existing node identity. Part of #1208.
