# Mealie — self-hosted recipe manager
# Built from source via forge mirror of mealie-recipes/mealie
# Based on upstream docker/Dockerfile (multi-stage: Node frontend + Python backend)

ARG CONTAINER_APP_VERSION=v3.12.0

###############################################
# Frontend Build
###############################################
FROM node:24-slim AS frontend-builder

ARG CONTAINER_APP_VERSION
RUN apt-get update && apt-get install --no-install-recommends -y git ca-certificates && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${CONTAINER_APP_VERSION} \
    https://forge.ops.eblu.me/mirrors/mealie.git /src

WORKDIR /src/frontend

RUN yarn install \
    --prefer-offline \
    --frozen-lockfile \
    --non-interactive \
    --production=false \
    --network-timeout 1000000

RUN yarn generate

###############################################
# Python Base
###############################################
FROM python:3.12-slim AS python-base

ENV MEALIE_HOME="/app"
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    VENV_PATH="/opt/mealie"

ENV PATH="$VENV_PATH/bin:$PATH"

RUN useradd -u 911 -U -d $MEALIE_HOME -s /bin/bash abc \
    && usermod -G users abc \
    && mkdir $MEALIE_HOME

###############################################
# Backend Package Build
###############################################
FROM python-base AS backend-builder

ARG CONTAINER_APP_VERSION
RUN apt-get update \
    && apt-get install --no-install-recommends -y curl git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN pip install uv

RUN git clone --depth 1 --branch ${CONTAINER_APP_VERSION} \
    https://forge.ops.eblu.me/mirrors/mealie.git /src

WORKDIR /src

COPY --from=frontend-builder /src/frontend/dist ./mealie/frontend

RUN uv build --out-dir dist

RUN uv export --no-editable --no-emit-project --extra pgsql --format requirements-txt --output-file dist/requirements.txt \
    && MEALIE_VERSION=$(python -c "import tomllib; print(tomllib.load(open('pyproject.toml', 'rb'))['project']['version'])") \
    && echo "mealie[pgsql]==${MEALIE_VERSION} \\" >> dist/requirements.txt \
    && pip hash dist/mealie-${MEALIE_VERSION}-py3-none-any.whl | tail -n1 | tr -d '\n' >> dist/requirements.txt \
    && echo " \\" >> dist/requirements.txt \
    && pip hash dist/mealie-${MEALIE_VERSION}.tar.gz | tail -n1 >> dist/requirements.txt

###############################################
# Python Venv Build
###############################################
FROM python-base AS venv-builder

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    build-essential \
    libpq-dev \
    libwebp-dev \
    ffmpeg \
    libsasl2-dev libldap2-dev libssl-dev \
    gnupg gnupg2 gnupg1 \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv --upgrade-deps $VENV_PATH

COPY --from=backend-builder /src/dist /dist

RUN . $VENV_PATH/bin/activate \
    && pip install --require-hashes -r /dist/requirements.txt --find-links /dist

###############################################
# Production Image
###############################################
FROM python-base AS production

ENV PRODUCTION=true
ENV TESTING=false

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    curl \
    ffmpeg \
    gosu \
    iproute2 \
    libldap-common \
    libldap2 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/secrets

COPY --from=venv-builder $VENV_PATH $VENV_PATH

ENV NLTK_DATA="/nltk_data/"
RUN mkdir -p $NLTK_DATA
RUN python -m nltk.downloader -d $NLTK_DATA averaged_perceptron_tagger_eng

VOLUME ["$MEALIE_HOME/data/"]
ENV APP_PORT=9000

EXPOSE ${APP_PORT}

COPY --from=backend-builder /src/docker/healthcheck.sh $MEALIE_HOME/healthcheck.sh
RUN chmod +x $MEALIE_HOME/healthcheck.sh
HEALTHCHECK CMD $MEALIE_HOME/healthcheck.sh

ENV HOST=0.0.0.0

COPY --from=backend-builder /src/docker/entry.sh $MEALIE_HOME/run.sh
RUN chmod +x $MEALIE_HOME/run.sh

LABEL org.opencontainers.image.title="Mealie"
LABEL org.opencontainers.image.description="Self-hosted recipe manager"
LABEL org.opencontainers.image.source="https://github.com/mealie-recipes/mealie"

ENTRYPOINT ["/app/run.sh"]
