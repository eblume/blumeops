# TeslaMate - Tesla data logger
# Based on upstream Dockerfile

ARG CONTAINER_APP_VERSION=v2.2.0
ARG TESLAMATE_VERSION=${CONTAINER_APP_VERSION}

FROM elixir:1.18-otp-26 AS builder

ARG TESLAMATE_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y ca-certificates curl gnupg git \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
     | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && NODE_MAJOR=22 \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" \
     | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install nodejs -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mix local.rebar --force && \
    mix local.hex --force

# Clone specific version
RUN git clone --depth 1 --branch ${TESLAMATE_VERSION} \
    https://forge.ops.eblu.me/mirrors/teslamate.git /opt/app

ENV MIX_ENV=prod
WORKDIR /opt/app

RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

RUN npm ci --prefix ./assets --progress=false --no-audit --loglevel=error
RUN mix assets.deploy

RUN mix compile
RUN SKIP_LOCALE_DOWNLOAD=true mix release --path /opt/built

# Runtime image
FROM debian:bookworm-slim AS app

ENV LANG=C.UTF-8 \
    SRTM_CACHE=/opt/app/.srtm_cache \
    HOME=/opt/app

WORKDIR $HOME

RUN apt-get update && apt-get install -y --no-install-recommends \
        libodbc2 \
        libsctp1 \
        libssl3 \
        libstdc++6 \
        netcat-openbsd \
        tini \
        tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 --system nonroot \
    && useradd --uid 10000 --system --gid nonroot --home-dir /home/nonroot --shell /sbin/nologin nonroot \
    && chown -R nonroot:nonroot .

COPY entrypoint.sh /
COPY --from=builder /opt/built .
RUN chmod 555 /entrypoint.sh && \
    chown -R nonroot:nonroot . && \
    mkdir $SRTM_CACHE

USER nonroot:nonroot

EXPOSE 4000

ENTRYPOINT ["tini", "--", "/bin/dash", "/entrypoint.sh"]
CMD ["bin/teslamate", "start"]
