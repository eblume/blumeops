# nginx 1.30.5-alpine
FROM nginx@sha256:25820c39dba41369486df729ad6697de2fab631ca809e0503e1d1e0c73d9a232

# Copy tailscale binaries from official image (v1.102.3)
COPY --from=docker.io/tailscale/tailscale@sha256:8c42c4574ab066384fcb72f69e086a2ff1dd3652eb6f56856cee34bcf0d2f680 \
    /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=docker.io/tailscale/tailscale@sha256:8c42c4574ab066384fcb72f69e086a2ff1dd3652eb6f56856cee34bcf0d2f680 \
    /usr/local/bin/tailscale /usr/local/bin/tailscale

RUN mkdir -p /var/run/tailscale /var/lib/tailscale \
    && apk add --no-cache iptables ip6tables \
    && apk add --no-cache libc6-compat \
    && apk add --no-cache fail2ban \
    && rm -f /etc/fail2ban/jail.d/alpine-ssh.conf \
    # Static forge mirror (staging vhost blumeops-proxy.fly.dev, see
    # fly/git-mirror/README.md): git for bare mirror repos + dumb HTTP
    # (update-server-info), openssh-server for the forced git-shell
    # `mirror` user that receives Forgejo push-mirror pushes, stagit to
    # generate the browsable HTML (Alpine community stagit is the C
    # version; the single-shell stagit fork it was modeled on is gone).
    # None of the allowlisted repos carries LFS (no .gitattributes,
    # verified 2026-09-25), so no git-lfs. util-linux (mountpoint) and
    # jq (tailscale status --json parse) are used by start.sh.
    && apk add --no-cache git=2.54.0-r0 openssh-server=10.3_p1-r1 stagit=1.2-r8 util-linux jq

# Copy Alloy binary from official image (v1.19.2, Ubuntu-based, needs libc6-compat)
COPY --from=docker.io/grafana/alloy@sha256:b8ec653c44235fbe910879145dac3597d66b0aaecf60bcbbe82580767771a839 \
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
COPY fail2ban/filter.d/photos-share.conf /etc/fail2ban/filter.d/photos-share.conf
COPY fail2ban/jail.d/photos.conf /etc/fail2ban/jail.d/photos.conf
COPY fail2ban/action.d/nginx-deny.conf /etc/fail2ban/action.d/nginx-deny.conf

COPY nginx.conf /etc/nginx/nginx.conf
COPY error.html /usr/share/nginx/html/error.html
COPY tombstone.html /usr/share/nginx/html/tombstone.html
COPY naughty.html /usr/share/nginx/html/naughty.html
COPY landing/ /usr/share/nginx/html/landing/
COPY alloy.river /etc/alloy/config.alloy
COPY git-mirror/post-receive /usr/local/share/git-mirror/post-receive
COPY git-mirror/gen-index.sh /usr/local/share/git-mirror/gen-index.sh
COPY git-mirror/create-mirror.sh /usr/local/bin/create-mirror.sh
COPY git-mirror/repos /usr/share/git-mirror/repos
COPY git-mirror/authorized_keys /home/mirror/.ssh/authorized_keys
COPY git-mirror/assets/ /usr/share/git-mirror/assets/

# Mirror user: forced git-shell commands only, no login shell, so the
# authorized keys can run pushes but nothing else (see git-mirror/README.md).
# sshd runs with hardening via -o flags in start.sh (no password, no root).
RUN mkdir -p /home/mirror/.ssh \
    && chmod 700 /home/mirror/.ssh \
    && chmod 600 /home/mirror/.ssh/authorized_keys \
    && chmod 755 /usr/local/share/git-mirror/post-receive /usr/local/share/git-mirror/gen-index.sh /usr/local/bin/create-mirror.sh \
    && useradd -r -d /home/mirror -s /usr/bin/git-shell mirror \
    && chown -R mirror:mirror /home/mirror \
    && mkdir -p /run/sshd

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
