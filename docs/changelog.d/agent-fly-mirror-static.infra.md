fly.io proxy: build the static forge mirror (staging vhost on
blumeops-proxy.fly.dev — stagit HTML + git dumb HTTP on a Fly volume,
Anubis-fronted, 302 to forge.ops.eblu.me for non-static paths) and
persist the tailscale node key on the volume to retire the node-name
drift. Part of #1208.
