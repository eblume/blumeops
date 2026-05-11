Wire shower app for public exposure: fly nginx `shower.eblu.me` server
block as a guest-only surface — splash page, `/prizes/<token>/`, static
assets, media. Everything authenticated (`/admin/`, `/host/`,
`/accounts/`) returns 403 with a "tailnet only" pointer. Staff hit
`shower.ops.eblu.me` for the operator console + admin; the app's
v1.0.1 `DJANGO_PUBLIC_URL_BASE` setting makes QR codes generated on
the tailnet point back at the WAN host for guests. Plus a Caddy route
on indri, Pulumi Gandi CNAME, and a Grafana APM dashboard tracking
request rate, error rate, latency, bandwidth, and access logs.
