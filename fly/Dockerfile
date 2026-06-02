# nginx 1.30.1-alpine
FROM nginx@sha256:c819f83c54b0361f5557601bf5eb4943d09360e7a7fdf426afc466570f45874d

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

# Copy Alloy binary from official image (v1.16.1, Ubuntu-based, needs libc6-compat)
COPY --from=docker.io/grafana/alloy@sha256:51aeb9d829239345070619dad3edd6873186f913c84f45b365b74574fcb38ec0 \
    /bin/alloy /usr/local/bin/alloy

RUN mkdir -p /var/log/nginx /etc/alloy /tmp/alloy-data

COPY fail2ban/filter.d/forge-login.conf /etc/fail2ban/filter.d/forge-login.conf
COPY fail2ban/jail.d/forge.conf /etc/fail2ban/jail.d/forge.conf
COPY fail2ban/action.d/nginx-deny.conf /etc/fail2ban/action.d/nginx-deny.conf

COPY nginx.conf /etc/nginx/nginx.conf
COPY error.html /usr/share/nginx/html/error.html
COPY naughty.html /usr/share/nginx/html/naughty.html
COPY alloy.river /etc/alloy/config.alloy
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
