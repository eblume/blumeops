FROM nginx:1.28.2-alpine

# Copy tailscale binaries from official image
COPY --from=docker.io/tailscale/tailscale:stable \
    /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=docker.io/tailscale/tailscale:stable \
    /usr/local/bin/tailscale /usr/local/bin/tailscale

RUN mkdir -p /var/run/tailscale /var/lib/tailscale \
    && apk add --no-cache iptables ip6tables \
    && apk add --no-cache libc6-compat \
    && apk add --no-cache fail2ban \
    && rm -f /etc/fail2ban/jail.d/alpine-ssh.conf

# Copy Alloy binary from official image (Ubuntu-based, needs libc6-compat)
COPY --from=docker.io/grafana/alloy:v1.13.1 \
    /bin/alloy /usr/local/bin/alloy

RUN mkdir -p /var/log/nginx /etc/alloy /tmp/alloy-data

COPY fail2ban/filter.d/forge-login.conf /etc/fail2ban/filter.d/forge-login.conf
COPY fail2ban/jail.d/forge.conf /etc/fail2ban/jail.d/forge.conf
COPY fail2ban/action.d/nginx-deny.conf /etc/fail2ban/action.d/nginx-deny.conf

COPY nginx.conf /etc/nginx/nginx.conf
COPY error.html /usr/share/nginx/html/error.html
COPY alloy.river /etc/alloy/config.alloy
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
