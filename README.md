# 🏃 lema-actions-runner

[![Build runner image](https://github.com/lema-ufpb/lema-actions-runner/actions/workflows/build.yml/badge.svg)](https://github.com/lema-ufpb/lema-actions-runner/actions/workflows/build.yml)
![Imagem](https://img.shields.io/badge/ghcr.io-lema--ufpb%2Factions--runner-blue?logo=github)
![Licença](https://img.shields.io/badge/licen%C3%A7a-MIT-green)

Imagem de contêiner do **runner de GitHub Actions self-hosted** do LEMA-UFPB, usada pelo
scale set `lema-k8s` do [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller)
no cluster Kubernetes. Publicada em `ghcr.io/lema-ufpb/actions-runner`.

> 🔒 **Resumo de segurança:** sem daemon Docker, execução sem root (uid 1001), ferramentas com
> versão e SHA-256 fixados, scan do Trivy como gate de publicação, SBOM e provenance em cada imagem.

## 📑 Sumário

- [📦 O que tem na imagem](#-o-que-tem-na-imagem)
- [🚀 Como usar](#-como-usar)
- [🏷️ Tags](#️-tags)
- [🔄 Como atualizar](#-como-atualizar)
- [🛡️ Segurança](#️-segurança)
- [⚙️ Automação (CI)](#️-automação-ci)
- [📌 Publicação no GHCR](#-publicação-no-ghcr)
- [🌐 Política: repositório público, runner hospedado](#-política-repositório-público-runner-hospedado)
- [🧰 Solução de problemas](#-solução-de-problemas)
- [🤝 Contribuindo](#-contribuindo)
- [📄 Licença](#-licença)

## 📦 O que tem na imagem

Base oficial `ghcr.io/actions/actions-runner` (inclui `docker` CLI e `buildx`) mais:

| Ferramenta | Origem | Verificação |
|---|---|---|
| `uv`, `uvx` | release do GitHub | SHA-256 fixado |
| `node` / `npm` (LTS) | nodejs.org; `npm` atualizado via `npm install -g npm@<fixa>` | SHA-256 fixado (node) |
| `docker` (CLI), `docker buildx`, `docker compose` | download.docker.com / release do GitHub | SHA-256 fixado (substituem os da base, que têm CVEs de Go) |
| `kustomize` | release do GitHub | SHA-256 fixado |
| `trivy` | release do GitHub | SHA-256 fixado |
| `gh` (GitHub CLI) | release do GitHub | SHA-256 fixado |
| `yq` | release do GitHub | SHA-256 fixado |
| `gcc`, `g++`, `libc6-dev`, `make` | apt (Ubuntu 24.04) | assinatura do apt |
| bibliotecas do Chromium headless (`libnss3`, `libgbm1`, `libatk*` etc.) e fontes básicas | apt (Ubuntu 24.04) | assinatura do apt |
| `netcat-openbsd` (`nc`), `rsync`, `jq`, `curl`, `git`, `zip`, `unzip` | apt (Ubuntu 24.04) | assinatura do apt |

🔧 **Compilador C/C++:** necessário para dependências que não publicam wheel e são compiladas
na instalação (por exemplo, `pyreaddbc` com `uv sync` em Python 3.14). Sem ele o job falha com
`No such file or directory: 'cc'`, o que não acontece nos runners hospedados do GitHub.

🎭 **Playwright sem `sudo`:** o runner não tem `sudo`, então `npx playwright install --with-deps` falha (`no new privileges`). As bibliotecas de sistema do Chromium já estão na imagem; no job use só `npx playwright install chromium` (só baixa o navegador). Em runner hospedado mantenha `--with-deps`.

📄 **Não está na imagem:** `pandoc` e Chrome/Chromium completo (o pipeline de PDF do `mir-odsr-docs` usa Chrome 122+). Esses jobs ficam em runner hospedado; embutir um navegador completo em toda imagem não compensa.

🐳 **Não há daemon Docker na imagem, por design.** Os binários do Docker Engine que a base
traz (`dockerd`, `containerd`, `containerd-shim*`, `ctr`, `runc`, `docker-proxy`,
`docker-init`) são removidos no `Dockerfile`: nunca são usados aqui e carregariam
dezenas de CVEs de Go. Ficam só o CLI `docker` e o plugin `buildx`. Builds usam `docker buildx`
com o driver `remote`, apontando para o BuildKit do cluster. O processo roda como `runner`
(sem root).

## 🚀 Como usar

Os workflows escolhem o runner pelo label do scale set:

```yaml
jobs:
  build:
    runs-on: lema-k8s
```

Para builds de imagem, use o BuildKit remoto do cluster (os certificados mTLS são montados
em `/certs/buildkit` pelo scale set):

```bash
docker buildx create --name lema --driver remote \
  --driver-opt cacert=/certs/buildkit/ca.crt,cert=/certs/buildkit/tls.crt,key=/certs/buildkit/tls.key \
  tcp://buildkit-ci.buildkit.svc.cluster.local:1234
docker buildx build --builder lema .
```

Para puxar a imagem manualmente (o pacote é público):

```bash
docker pull ghcr.io/lema-ufpb/actions-runner:<tag>
```

> 💡 A configuração do scale set (ARC, BuildKit, NetworkPolicy) fica no repositório `lema-deploy`.

## 🏷️ Tags

| Tag | Uso |
|---|---|
| `<versão-do-runner>-lema.N.A`, ex.: `2.338.0-lema.3.1` | ✅ **Fixar esta no cluster.** Imutável por convenção: `N` = número da execução do workflow, `A` = tentativa; re-runs geram tag nova e não sobrescrevem a anterior. |
| `latest` | ⚠️ Ponteiro móvel, só por conveniência. Não usar em produção. |

📍 Em produção o `lema-deploy` fixa a imagem **por digest** (`tag@sha256:...`).

## 🔄 Como atualizar

### ⬆️ Versão do runner

> ⚠️ **Este runner roda SEM auto-update.** O GitHub deixa de despachar jobs para runners com
> mais de ~30 dias de defasagem em relação à última versão do runner. Se a imagem não for
> reconstruída com a versão nova a tempo, o scale set para de receber jobs. O rebuild semanal
> não resolve isso: ele reaproveita a versão fixada da base. **Atualize a versão assim que uma
> release nova sair.**

1. Confira a nova versão em <https://github.com/actions/runner/releases> e se a tag
   existe em `ghcr.io/actions/actions-runner`.
2. Obtenha o digest: `docker buildx imagetools inspect ghcr.io/actions/actions-runner:<versão>`
   (campo `Digest` do índice multi-arch).
3. Altere `ARG RUNNER_VERSION` e `ARG RUNNER_DIGEST` no `Dockerfile`.
4. Abra PR. Ao entrar em `main`, o workflow `Build runner image` publica a nova tag.
5. No repositório `lema-deploy`, atualize a tag e o digest da imagem no scale set `arc-runners`.

### 🧩 Ferramentas (uv, node, kustomize, trivy, gh, yq)

Altere `*_VERSION` e o `*_SHA256` correspondente no `Dockerfile`. Os checksums vêm dos
arquivos publicados pelo próprio projeto (`*.sha256`, `SHASUMS256.txt`, `checksums.txt`) ou,
quando não existem, do `sha256sum` do binário baixado. O build falha se o checksum não bater.

### 🧪 Testar a imagem localmente

```bash
make help          # lista os alvos
make docker-build  # constrói lema-runner:local (NO_CACHE=1 refaz tudo)
make docker-test   # confere que as ferramentas rodam como usuário runner (uid 1001)
make docker-scan   # Trivy (container, mesma versão do CI) com .trivyignore.yaml; não precisa instalar o trivy
```

Variáveis: `IMAGE_NAME`, `IMAGE_TAG`, `PLATFORM` (padrão `linux/amd64`, o mesmo do runner) e `TRIVY_VERSION` (a que o `trivy-action` do CI usa).
Rode `make docker-scan` antes de abrir PR: se falhar aqui, falha no CI.

## 🛡️ Segurança

### 🔍 Scan de vulnerabilidades (Trivy)

O workflow escaneia a imagem antes de publicar e falha (`exit-code: 1`) em achados
HIGH/CRITICAL com correção disponível (`ignore-unfixed`). O build também roda
`apt-get upgrade` para absorver patches do Ubuntu.

Exceções ficam em [`.trivyignore.yaml`](.trivyignore.yaml): cada CVE é listado
explicitamente, **escopado ao caminho do componente** (nada é silenciado globalmente) e com
`expired_at`. São achados em componentes que não controlamos: o npm embutido em
`/home/runner/externals`, as dependências .NET em `/home/runner/bin` (ambos do runner
oficial) e a toolchain Go dos releases mais recentes de `kustomize`, `yq` e `buildx`.
Ao expirar, o gate volta a falhar, forçando a revisão (atualizar runner/ferramentas e
remover as entradas já corrigidas). Para listar o que ainda é necessário:
`trivy image --severity HIGH,CRITICAL --ignore-unfixed <imagem>` sem o ignorefile.

### 🧱 Princípios

- 🚫 Sem daemon Docker e sem `privileged`; o processo não roda como root.
- 📌 Tudo fixado: base por digest, ferramentas por versão e SHA-256, actions por SHA de commit.
- 🧾 Cada imagem publicada leva SBOM e provenance.

## ⚙️ Automação (CI)

| Gatilho | O que faz |
|---|---|
| `push` em `main` que altere `Dockerfile`, `.trivyignore.yaml` ou `.github/workflows/build.yml` | Build, scan e publicação da nova tag |
| Semanal (segunda, 05:00 UTC) | Rebuild para absorver correções de pacotes apt do Ubuntu (a base é fixada por digest) |
| `workflow_dispatch` | Rebuild manual |
| Dependabot (mensal, agrupado) | Atualiza as GitHub Actions e a imagem base |

## 📌 Publicação no GHCR

O pacote `ghcr.io/lema-ufpb/actions-runner` nasce **privado** no primeiro push. Depois do
primeiro push, torne-o público em *Package settings → Change visibility* (a imagem não contém
nada sensível), para que o cluster possa puxá-la sem `imagePullSecret`.

## 🌐 Política: repositório público, runner hospedado

Este repositório é **público** de propósito: assim o build em runner hospedado do GitHub
(`ubuntu-24.04`) não consome minutos pagos da organização. Por isso:

- ⛔ **Nunca usar runner self-hosted aqui.** Runner self-hosted em repositório público permite
  que PRs de forks executem código na nossa rede.
- 🔐 **Nada sensível no repositório ou na imagem:** sem segredos, sem endereços internos, sem
  credenciais. Tudo que está na imagem é público.
- 🎟️ O único segredo usado é o `GITHUB_TOKEN` efêmero (`packages: write`) para publicar no GHCR.
- 📎 As actions são fixadas por SHA de commit.

## 🧰 Solução de problemas

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| Job falha com `No such file or directory: 'cc'` | imagem antiga, sem compilador | usar uma tag com `gcc`/`g++` (ver [O que tem na imagem](#-o-que-tem-na-imagem)) |
| Scale set não recebe jobs | runner com mais de ~30 dias de defasagem | atualizar a versão do runner ([guia](#️-versão-do-runner)) |
| Build do CI falha no Trivy | CVE novo com correção disponível | atualizar a ferramenta ou a base; exceção só com escopo e `expired_at` |
| `403`/`denied` ao puxar a imagem | pacote voltou a ser privado | tornar o pacote público ([instruções](#-publicação-no-ghcr)) |

## 🤝 Contribuindo

1. Crie uma branch a partir de `main` e faça a mudança no `Dockerfile` (ou no workflow).
2. Teste o build localmente ([como](#-testar-a-imagem-localmente)).
3. Use [Conventional Commits](https://www.conventionalcommits.org/pt-br/) (`feat:`, `fix:`, `ci:`, `docs:`).
4. Abra o PR. O workflow **não roda em PR**: build, scan e publicação só acontecem após o merge em `main`, por isso o teste local (passo 2) e o scan com `trivy image` são a sua checagem antes do merge.

## 📄 Licença

MIT. Veja [LICENSE](LICENSE).
