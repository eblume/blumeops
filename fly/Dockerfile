# nginx 1.30.4-alpine
FROM nginx@sha256:97d490c12ba55b4946b01546d1c3ed324e8d41ab1c9fcb2a616aa470620e5b46

# Copy tailscale binaries from official image (v1.94.2)
COPY --from=docker.io/tailscale/tailscale@sha256:95e528798bebe75f39b10e74e7051cf51188ee615934f232ba7ad06a3390ffa1 \
    /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=docker.io/tailscale/tailscale@sha256:95e528798bebe75f39b10e74e7051cf51188ee615934f232ba7ad06a3390ffa1 \
    /usr/local/bin/tailscale /usr/local/bin/tailscale

RUN mkdir -p /var/run/tailscale /var/lib/tailscale \
    && apk add --no-cache iptables ip6tables \
    && apk add --no-cache libc6-compat \
    && apk add --no-cache fail2ban \
    && rm -f /etc/fail2ban/jail.d/alpine-ssh.conf

# Copy Alloy binary from official image (v1.18.0, Ubuntu-based, needs libc6-compat)
COPY --from=docker.io/grafana/alloy@sha256:491b0578c04983fd54fe99b587b6fab4404dc46d0dc16677bd6b00cc1140b308 \
    /bin/alloy /usr/local/bin/alloy

# Copy Anubis binary from official image (v1.25.0, ko-built static binary
# with embedded assets) — proof-of-work gateway for forge.eblu.me
COPY --from=ghcr.io/techarohq/anubis@sha256:5cf4c0d6c7ea01a356c6685a779971bdd28d6a5a4a6719201f73a9c4ae108db0 \
    /ko-app/anubis /usr/local/bin/anubis

RUN mkdir -p /var/log/nginx /etc/alloy /tmp/alloy-data

COPY fail2ban/filter.d/forge-login.conf /etc/fail2ban/filter.d/forge-login.conf
COPY fail2ban/jail.d/forge.conf /etc/fail2ban/jail.d/forge.conf
COPY fail2ban/action.d/nginx-deny.conf /etc/fail2ban/action.d/nginx-deny.conf

COPY nginx.conf /etc/nginx/nginx.conf
COPY error.html /usr/share/nginx/html/error.html
COPY naughty.html /usr/share/nginx/html/naughty.html
COPY landing/ /usr/share/nginx/html/landing/
COPY alloy.river /etc/alloy/config.alloy
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
