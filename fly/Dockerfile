# nginx 1.30.6-alpine
FROM nginx@sha256:970364228b1e4f932abc22d321932816782cca8a20b85a77552a7cfe9acfb3b5

# Copy tailscale binaries from official image (v1.104.1)
COPY --from=docker.io/tailscale/tailscale@sha256:87c55d6be56ad85b3d8bceca5f87f73de288c609131460dd1be1874c250cc41d \
    /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=docker.io/tailscale/tailscale@sha256:87c55d6be56ad85b3d8bceca5f87f73de288c609131460dd1be1874c250cc41d \
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
    # shadow provides useradd for the `mirror` user created below (the
    # nginx:alpine base ships no account tools).
    # None of the allowlisted repos carries LFS (no .gitattributes,
    # verified 2026-09-25), so no git-lfs. util-linux (mountpoint) and
    # jq (tailscale status --json parse) are used by start.sh.
    && apk add --no-cache git=2.54.0-r0 openssh-server=10.3_p1-r1 stagit=1.2-r8 util-linux jq shadow=4.18.0-r1

# Copy Alloy binary from official image (v1.20.1, Ubuntu-based, needs libc6-compat)
COPY --from=docker.io/grafana/alloy@sha256:2aa2099af76c0098d4af7a4d6e48f86cb66dc1a000222ad927a1c67c6542d13f \
    /bin/alloy /usr/local/bin/alloy

# Copy Anubis binary from official image (v1.28.1, ko-built static binary
# with embedded assets) — proof-of-work gateway for forge.eblu.me.
# Cookie names are derived from the cookie settings, so COOKIE_PREFIX is not a
# stable string; nothing here reads the cookie by name.
COPY --from=ghcr.io/techarohq/anubis@sha256:1744c03a918160a28b0d2e8c1656de6585f4071b30b4c3b0d51d02282c9b7c25 \
    /ko-app/anubis /usr/local/bin/anubis

RUN mkdir -p /var/log/nginx /etc/alloy /tmp/alloy-data

COPY fail2ban/filter.d/photos-share.conf /etc/fail2ban/filter.d/photos-share.conf
COPY fail2ban/jail.d/photos.conf /etc/fail2ban/jail.d/photos.conf
COPY fail2ban/action.d/nginx-deny.conf /etc/fail2ban/action.d/nginx-deny.conf

COPY nginx.conf /etc/nginx/nginx.conf
COPY error.html /usr/share/nginx/html/error.html
COPY tombstone.html /usr/share/nginx/html/tombstone.html
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
    # useradd leaves the password field "!" (locked), and sshd without PAM
    # refuses a locked account even for key auth ("account is locked").
    # "*" means no usable password without locking the account.
    && usermod -p '*' mirror \
    && chown -R mirror:mirror /home/mirror \
    && mkdir -p /run/sshd \
    # create-mirror.sh runs as root on every boot but the repos are owned
    # by `mirror` after the first one, so git (and stagit's libgit2) refuse
    # them as dubious ownership. Single-purpose image: trust them all.
    && git config --system --add safe.directory '*'

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
