# Imagem do runner self-hosted (ARC) do LEMA-UFPB.
# Base oficial + ferramentas de CI com versão FIXADA e checksum SHA-256 verificado.
# Sem daemon Docker: o CLI e o buildx da base falam com o BuildKit remoto.
# O digest fixa a base de forma imutável; ao mudar RUNNER_VERSION, atualize o digest (ver README).
ARG RUNNER_VERSION=2.338.0
ARG RUNNER_DIGEST=sha256:4ffadc0002b2581327e06101fc8c06cd189232baf79fe561fac9caeb76f5e807
FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}@${RUNNER_DIGEST}

# Versões e checksums (linux amd64). Para atualizar: ver README.
ARG UV_VERSION=0.13.4
ARG UV_SHA256=2b428396f12572d4429cf210ca234dd599a33b3af0958a4d5ed569d63e3f344f
ARG NODE_VERSION=24.22.1
ARG NODE_SHA256=6c172a9ab6718f7b801fb5a7bd486af2ee5e32758086a04b84fcce2aa77095e6
ARG NPM_VERSION=11.21.1
ARG DOCKER_CLI_VERSION=29.9.2
ARG DOCKER_CLI_SHA256=9ac225999fd5e863f7694c728ef23d480616b1e5639328fa309befd4243d69eb
ARG BUILDX_VERSION=0.38.1
ARG BUILDX_SHA256=e25d5cd675092bb5d1d03632fdc46cdf3fede7b514dc5f023a105e00d3ce5ad4
ARG COMPOSE_VERSION=5.6.1
ARG COMPOSE_SHA256=47737f4236e6d3ccea7291995203f8f018058783b4c3a9469119811a0b5db8c0
ARG KUSTOMIZE_VERSION=5.8.3
ARG KUSTOMIZE_SHA256=cb9e31198d3f63b44848bd0afc4c8efc56e6cfef9c93a4a39a211940e6decd61
ARG TRIVY_VERSION=0.76.1
ARG TRIVY_SHA256=c7cbe3137fb8a48a17574bede3dd6beb16742d1e9772929940fc90082c39d9c0
ARG YQ_VERSION=4.54.1
ARG YQ_SHA256=8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f

USER 0
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Bibliotecas do Chromium headless (lista oficial do Playwright 1.64 para Ubuntu 24.04, sem xvfb nem fontes CJK):
# o job só baixa o navegador (`playwright install chromium`, sem `--with-deps`), pois o runner não tem sudo.
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && apt-get install -y --no-install-recommends ca-certificates curl g++ gcc git jq libc6-dev make netcat-openbsd rsync unzip xz-utils zip \
      libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 libatspi2.0-0t64 libcairo2 libcups2t64 libdbus-1-3 libdrm2 libgbm1 \
      libglib2.0-0t64 libnspr4 libnss3 libpango-1.0-0 libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3 \
      libxkbcommon0 libxrandr2 libfontconfig1 libfreetype6 fonts-liberation fonts-noto-color-emoji \
 && rm -rf /var/lib/apt/lists/*

# Esta imagem nunca roda daemon (builds vão para um BuildKit remoto): remove os binários
# Go do Docker Engine que a base traz (não são pacotes dpkg). Mantém o CLI `docker` e o buildx.
RUN rm -f /usr/bin/dockerd /usr/bin/containerd /usr/bin/containerd-shim* /usr/bin/ctr \
          /usr/bin/runc /usr/bin/docker-proxy /usr/bin/docker-init

# Baixa, confere o SHA-256 e extrai. Falha o build se o checksum divergir.
WORKDIR /tmp
# hadolint ignore=DL4006
RUN set -eux; \
    dl() { curl -fsSL --retry 3 -o "$1" "$2"; echo "$3  $1" | sha256sum -c -; }; \
    dl uv.tgz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" "${UV_SHA256}"; \
    tar -xzf uv.tgz --strip-components=1 -C /usr/local/bin uv-x86_64-unknown-linux-gnu/uv uv-x86_64-unknown-linux-gnu/uvx; \
    dl node.txz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" "${NODE_SHA256}"; \
    tar -xJf node.txz --strip-components=1 -C /usr/local --exclude=CHANGELOG.md --exclude=LICENSE --exclude=README.md; \
    npm install -g --no-audit --no-fund "npm@${NPM_VERSION}"; npm cache clean --force; \
    dl docker.tgz "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz" "${DOCKER_CLI_SHA256}"; \
    tar -xzf docker.tgz --strip-components=1 -C /usr/bin docker/docker; \
    dl buildx "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64" "${BUILDX_SHA256}"; \
    install -m 0755 buildx /usr/local/lib/docker/cli-plugins/docker-buildx; \
    dl compose "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" "${COMPOSE_SHA256}"; \
    install -m 0755 compose /usr/local/lib/docker/cli-plugins/docker-compose; \
    dl kustomize.tgz "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" "${KUSTOMIZE_SHA256}"; \
    tar -xzf kustomize.tgz -C /usr/local/bin kustomize; \
    dl trivy.tgz "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" "${TRIVY_SHA256}"; \
    tar -xzf trivy.tgz -C /usr/local/bin trivy; \
    dl yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" "${YQ_SHA256}"; \
    install -m 0755 yq /usr/local/bin/yq; \
    rm -rf /tmp/*; \
    uv --version; node --version; npm --version; kustomize version; trivy --version; yq --version; \
    rsync --version | sed -n 1p; make --version | sed -n 1p; cc --version | sed -n 1p; c++ --version | sed -n 1p; command -v nc; jq --version; docker --version; docker buildx version; docker compose version

# Runtime sem root: uid 1001 = `runner` na base.
WORKDIR /home/runner
USER 1001
