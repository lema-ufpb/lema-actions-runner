# lema-actions-runner

Imagem de contêiner do runner de GitHub Actions self-hosted do LEMA-UFPB, usada pelo
scale set `lema-k8s` do Actions Runner Controller (ARC) no cluster Kubernetes.

Publicada em `ghcr.io/lema-ufpb/actions-runner`.

## O que tem na imagem

Base oficial `ghcr.io/actions/actions-runner` (inclui `docker` CLI e `buildx`) mais:

| Ferramenta | Origem | Verificação |
|---|---|---|
| `uv`, `uvx` | release do GitHub | SHA-256 fixado |
| `node` / `npm` (LTS) | nodejs.org; `npm` atualizado via `npm install -g npm@<fixa>` | SHA-256 fixado (node) |
| `docker` (CLI), `docker buildx` | download.docker.com / release do GitHub | SHA-256 fixado (substituem os da base, que têm CVEs de Go) |
| `kustomize` | release do GitHub | SHA-256 fixado |
| `trivy` | release do GitHub | SHA-256 fixado |
| `yq` | release do GitHub | SHA-256 fixado |
| `make`, `netcat-openbsd` (`nc`), `rsync`, `jq`, `curl`, `git`, `zip`, `unzip` | apt (Ubuntu 24.04) | assinatura do apt |

**Não há daemon Docker na imagem, por design.** Os binários do Docker Engine que a base
traz (`dockerd`, `containerd`, `containerd-shim*`, `ctr`, `runc`, `docker-proxy`,
`docker-init`) são removidos no `Dockerfile`: nunca são usados aqui e carregariam
dezenas de CVEs de Go. Ficam só o CLI `docker` e o plugin `buildx`. Builds usam `docker buildx` com o driver `remote`,
apontando para o BuildKit do cluster. O processo roda como `runner` (sem root).

## Tags

- `<versão-do-runner>-lema.N.A`, por exemplo `2.337.0-lema.12.1`: imutável por convenção
  (`N` = número da execução do workflow, `A` = tentativa; re-runs geram tag nova e não
  sobrescrevem a anterior). **É esta que o cluster deve fixar.**
- `latest`: ponteiro móvel, só para conveniência. Não usar em produção.

## Como atualizar

### Versão do runner

> **Atenção: este runner roda SEM auto-update.** O GitHub deixa de despachar jobs para
> runners com mais de ~30 dias de defasagem em relação à última versão do runner. Se a
> imagem não for reconstruída com a versão nova a tempo, o scale set para de receber
> jobs. O rebuild semanal não resolve isso: ele reaproveita a versão fixada da base.
> Atualize a versão assim que uma release nova sair.

1. Confira a nova versão em <https://github.com/actions/runner/releases> e se a tag
   existe em `ghcr.io/actions/actions-runner`.
2. Obtenha o digest: `docker buildx imagetools inspect ghcr.io/actions/actions-runner:<versão>`
   (campo `Digest` do índice multi-arch).
3. Altere `ARG RUNNER_VERSION` e `ARG RUNNER_DIGEST` no `Dockerfile`.
4. Abra PR. Ao entrar em `main`, o workflow `Build runner image` publica a nova tag.
5. No repositório `lema-deploy`, atualize a tag da imagem no scale set `arc-runners`.

### Ferramentas (uv, node, kustomize, trivy, yq)

Altere `*_VERSION` e o `*_SHA256` correspondente no `Dockerfile`. Os checksums vêm
dos arquivos publicados pelo próprio projeto (`*.sha256`, `SHASUMS256.txt`,
`checksums.txt`) ou, quando não existem, do `sha256sum` do binário baixado. O build
falha se o checksum não bater.

### Scan de vulnerabilidades (Trivy)

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

### Rotina automática

- Semanal (segunda, 05:00 UTC): rebuild para absorver correções de pacotes apt do Ubuntu (a base é fixada por digest).
- O Dependabot (mensal, agrupado) atualiza as GitHub Actions e a imagem base.

## Publicação no GHCR

O pacote `ghcr.io/lema-ufpb/actions-runner` nasce **privado** no primeiro push. Depois do
primeiro push, torne-o público em *Package settings → Change visibility* (a imagem não
contém nada sensível), para que o cluster possa puxá-la sem `imagePullSecret`.

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
