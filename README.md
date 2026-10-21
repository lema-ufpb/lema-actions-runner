# lema-actions-runner

Imagem de contêiner do runner de GitHub Actions self-hosted do LEMA-UFPB, usada pelo
scale set `lema-k8s` do Actions Runner Controller (ARC) no cluster Kubernetes.

Publicada em `ghcr.io/lema-ufpb/actions-runner`.

## O que tem na imagem

Base oficial `ghcr.io/actions/actions-runner` (inclui `docker` CLI e `buildx`) mais:

| Ferramenta | Origem | Verificação |
|---|---|---|
| `uv`, `uvx` | release do GitHub | SHA-256 fixado |
| `node` / `npm` (LTS) | nodejs.org | SHA-256 fixado |
| `kustomize` | release do GitHub | SHA-256 fixado |
| `trivy` | release do GitHub | SHA-256 fixado |
| `yq` | release do GitHub | SHA-256 fixado |
| `rsync`, `jq`, `curl`, `git`, `zip`, `unzip` | apt (Ubuntu 24.04) | assinatura do apt |

Não há daemon Docker na imagem. Builds usam `docker buildx` com o driver `remote`,
apontando para o BuildKit do cluster. O processo roda como `runner` (sem root).

## Tags

- `<versão-do-runner>-lema.N`, por exemplo `2.337.0-lema.12`: imutável por convenção
  (`N` é o número da execução do workflow). **É esta que o cluster deve fixar.**
- `latest`: ponteiro móvel, só para conveniência. Não usar em produção.

## Como atualizar

### Versão do runner

1. Confira a nova versão em <https://github.com/actions/runner/releases> e se a tag
   existe em `ghcr.io/actions/actions-runner`.
2. Altere `ARG RUNNER_VERSION` no `Dockerfile`.
3. Abra PR. Ao entrar em `main`, o workflow `Build runner image` publica a nova tag.
4. No repositório `lema-deploy`, atualize a tag da imagem no scale set `arc-runners`.

### Ferramentas (uv, node, kustomize, trivy, yq)

Altere `*_VERSION` e o `*_SHA256` correspondente no `Dockerfile`. Os checksums vêm
dos arquivos publicados pelo próprio projeto (`*.sha256`, `SHASUMS256.txt`,
`checksums.txt`) ou, quando não existem, do `sha256sum` do binário baixado. O build
falha se o checksum não bater.

### Rotina automática

- Semanal (segunda, 05:00 UTC): rebuild para absorver correções da base e do Ubuntu.
- O Dependabot (mensal, agrupado) atualiza as GitHub Actions e a imagem base.

## Política: repositório público, runner hospedado

Este repositório é **público** de propósito: assim o build em runner hospedado do
GitHub (`ubuntu-24.04`) não consome minutos pagos da organização. Por isso:

- **Nunca usar runner self-hosted aqui.** Runner self-hosted em repositório público
  permite que PRs de forks executem código na nossa rede.
- **Nada sensível no repositório ou na imagem:** sem segredos, sem endereços internos,
  sem credenciais. Tudo que está na imagem é público.
- O único segredo usado é o `GITHUB_TOKEN` efêmero (`packages: write`) para publicar no GHCR.
- As actions são fixadas por SHA de commit.

## Licença

MIT. Veja [LICENSE](LICENSE).
