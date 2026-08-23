# nginx 1.30.4-alpine
FROM nginx@sha256:97d490c12ba55b4946b01546d1c3ed324e8d41ab1c9fcb2a616aa470620e5b46

# Copy tailscale binaries from official image (v1.102.3)
COPY --from=docker.io/tailscale/tailscale@sha256:8c42c4574ab066384fcb72f69e086a2ff1dd3652eb6f56856cee34bcf0d2f680 \
    /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=docker.io/tailscale/tailscale@sha256:8c42c4574ab066384fcb72f69e086a2ff1dd3652eb6f56856cee34bcf0d2f680 \
    /usr/local/bin/tailscale /usr/local/bin/tailscale

RUN mkdir -p /var/run/tailscale /var/lib/tailscale \
    && apk add --no-cache iptables ip6tables \
    && apk add --no-cache libc6-compat \
    && apk add --no-cache fail2ban \
    && rm -f /etc/fail2ban/jail.d/alpine-ssh.conf

# Copy Alloy binary from official image (v1.18.1, Ubuntu-based, needs libc6-compat)
COPY --from=docker.io/grafana/alloy@sha256:0f4434c92b3e6cdac38bb129b344e1790c246f7b6e2eaffcc16a5fa363240e33 \
    /bin/alloy /usr/local/bin/alloy

# Copy Anubis binary from official image (v1.27.0, ko-built static binary
# with embedded assets) — proof-of-work gateway for forge.eblu.me.
# Cookie names are derived from the cookie settings, so COOKIE_PREFIX is not a
# stable string; nothing here reads the cookie by name.
COPY --from=ghcr.io/techarohq/anubis@sha256:8828275668b7bc675679f100970f9714f731388fbbf66ae94de8aca952e3fc4a \
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
