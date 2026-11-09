# Imagem do runner self-hosted (ARC) do LEMA-UFPB.
# Base oficial + ferramentas de CI com versão FIXADA e checksum SHA-256 verificado.
# Sem daemon Docker: o CLI e o buildx da base falam com o BuildKit remoto.
# O digest fixa a base de forma imutável; ao mudar RUNNER_VERSION, atualize o digest (ver README).
ARG RUNNER_VERSION=2.338.2
ARG RUNNER_DIGEST=sha256:759a1d94a15b05941aba5196974ff43fe15b4cbba29b694b35cbc32a1166b232
FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}@${RUNNER_DIGEST}

# Versões e checksums (linux amd64). Para atualizar: ver README.
ARG UV_VERSION=0.13.4
ARG UV_SHA256=2b428396f12572d4429cf210ca234dd599a33b3af0958a4d5ed569d63e3f344f
ARG NODE_VERSION=24.22.2
ARG NODE_SHA256=48cc0e21e048790e54c0cf5749c2725005313d652651c40b7a21feb9697aaf75
ARG NPM_VERSION=11.21.1
ARG DOCKER_CLI_VERSION=29.9.2
ARG DOCKER_CLI_SHA256=9ac225999fd5e863f7694c728ef23d480616b1e5639328fa309befd4243d69eb
ARG BUILDX_VERSION=0.38.2
ARG BUILDX_SHA256=7992ec09413b80ff57ba4e081f56fc833d7bac1d5e71143c6c809e7e6065f6d6
ARG COMPOSE_VERSION=5.7.0
ARG COMPOSE_SHA256=7758048ad38e580f22559603312874fec8bb638d021a9e64182385fc17cc12a2
ARG KUSTOMIZE_VERSION=5.8.3
ARG KUSTOMIZE_SHA256=cb9e31198d3f63b44848bd0afc4c8efc56e6cfef9c93a4a39a211940e6decd61
ARG TRIVY_VERSION=0.76.2
ARG TRIVY_SHA256=bc0fc726e017b8927a62b2d3531d7a84ee01769daf5c99ed866dced54089fdbf
ARG GH_VERSION=2.103.3
ARG GH_SHA256=4c806978ffce1cec70853302a56d70ac6da4f19bae7adca4e1a8ab00633dd91d
ARG YQ_VERSION=4.54.3
ARG YQ_SHA256=129534601871538efe0ba4c5e62a34fb1d5f469bcb975c4fddeb467d82974973

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
    dl gh.tgz "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" "${GH_SHA256}"; \
    tar -xzf gh.tgz --strip-components=2 -C /usr/local/bin gh_${GH_VERSION}_linux_amd64/bin/gh; \
    dl yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" "${YQ_SHA256}"; \
    install -m 0755 yq /usr/local/bin/yq; \
    rm -rf /tmp/*; \
    uv --version; node --version; npm --version; kustomize version; trivy --version; gh --version | sed -n 1p; yq --version; \
    rsync --version | sed -n 1p; make --version | sed -n 1p; cc --version | sed -n 1p; c++ --version | sed -n 1p; command -v nc; jq --version; docker --version; docker buildx version; docker compose version

# Runtime sem root: uid 1001 = `runner` na base.
WORKDIR /home/runner
USER 1001
