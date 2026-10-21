# Imagem do runner self-hosted (ARC) do LEMA-UFPB.
# Base oficial + ferramentas de CI com versão FIXADA e checksum SHA-256 verificado.
# Sem daemon Docker: o CLI e o buildx da base falam com o BuildKit remoto.
# O digest fixa a base de forma imutável; ao mudar RUNNER_VERSION, atualize o digest (ver README).
ARG RUNNER_VERSION=2.337.0
ARG RUNNER_DIGEST=sha256:e5496277be5d09bc968b3d64911b74e219ac4a3f2edce956a3ecf9271bea1ef4
FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}@${RUNNER_DIGEST}

# Versões e checksums (linux amd64). Para atualizar: ver README.
ARG UV_VERSION=0.13.4
ARG UV_SHA256=2b428396f12572d4429cf210ca234dd599a33b3af0958a4d5ed569d63e3f344f
ARG NODE_VERSION=24.22.1
ARG NODE_SHA256=6c172a9ab6718f7b801fb5a7bd486af2ee5e32758086a04b84fcce2aa77095e6
ARG KUSTOMIZE_VERSION=5.8.3
ARG KUSTOMIZE_SHA256=cb9e31198d3f63b44848bd0afc4c8efc56e6cfef9c93a4a39a211940e6decd61
ARG TRIVY_VERSION=0.76.1
ARG TRIVY_SHA256=c7cbe3137fb8a48a17574bede3dd6beb16742d1e9772929940fc90082c39d9c0
ARG YQ_VERSION=4.54.1
ARG YQ_SHA256=8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f

USER 0
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git jq make netcat-openbsd rsync unzip xz-utils zip \
 && rm -rf /var/lib/apt/lists/*

# Baixa, confere o SHA-256 e extrai. Falha o build se o checksum divergir.
WORKDIR /tmp
# hadolint ignore=DL4006
RUN set -eux; \
    dl() { curl -fsSL --retry 3 -o "$1" "$2"; echo "$3  $1" | sha256sum -c -; }; \
    dl uv.tgz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" "${UV_SHA256}"; \
    tar -xzf uv.tgz --strip-components=1 -C /usr/local/bin uv-x86_64-unknown-linux-gnu/uv uv-x86_64-unknown-linux-gnu/uvx; \
    dl node.txz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" "${NODE_SHA256}"; \
    tar -xJf node.txz --strip-components=1 -C /usr/local --exclude=CHANGELOG.md --exclude=LICENSE --exclude=README.md; \
    dl kustomize.tgz "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" "${KUSTOMIZE_SHA256}"; \
    tar -xzf kustomize.tgz -C /usr/local/bin kustomize; \
    dl trivy.tgz "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" "${TRIVY_SHA256}"; \
    tar -xzf trivy.tgz -C /usr/local/bin trivy; \
    dl yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" "${YQ_SHA256}"; \
    install -m 0755 yq /usr/local/bin/yq; \
    rm -f /tmp/*; \
    uv --version; node --version; npm --version; kustomize version; trivy --version; yq --version; \
    rsync --version | head -n1; make --version | head -n1; command -v nc; jq --version; docker --version; docker buildx version

# Runtime sem root: uid 1001 = `runner` na base.
WORKDIR /home/runner
USER 1001
