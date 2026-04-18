Fixed forge.eblu.me static assets (CSS, JS, images, fonts) not loading — the proxy's static asset cache block was missing the `Host` header, so Caddy couldn't route the requests.
