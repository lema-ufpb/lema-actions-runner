.PHONY: help docker-build docker-test docker-scan

IMAGE_NAME ?= lema-runner
IMAGE_TAG ?= local
PLATFORM ?= linux/amd64
# Versão padrão do trivy-action usado no build.yml (o CI não fixa; confira no log do job).
TRIVY_VERSION ?= 0.70.0

help: ## 📋 Mostra esta mensagem de ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

docker-build: ## 🐳 Construir a imagem do runner (NO_CACHE=1 refaz tudo)
	@echo "🐳 Montando a imagem do runner ($(PLATFORM))..."
	docker build --platform $(PLATFORM) --pull $(if $(NO_CACHE),--no-cache) -t $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "✅ Imagem construída!"

docker-test: docker-build ## 🧪 Conferir se as ferramentas rodam na imagem como usuário runner
	@echo "🧪 Testando as ferramentas da imagem..."
	@docker run --rm --platform $(PLATFORM) --entrypoint bash $(IMAGE_NAME):$(IMAGE_TAG) -euc '\
	  test "$$(id -u)" = 1001; \
	  for c in uv node npm gh kustomize trivy yq jq docker rsync make cc nc git; do command -v $$c >/dev/null || { echo "❌ $$c ausente"; exit 1; }; done; \
	  gh --version | sed -n 1p; docker buildx version; docker compose version'
	@echo "✅ Ferramentas ok!"

docker-scan: docker-build ## 🔍 Escanear a imagem com Trivy (mesmo gate e versão do CI: HIGH/CRITICAL com correção)
	@echo "💾 Salvando imagem em tar (Trivy em container não acessa o socket Docker)..."
	@docker save $(IMAGE_NAME):$(IMAGE_TAG) -o /tmp/$(IMAGE_NAME).tar
	@echo "🔍 Escaneando com Trivy $(TRIVY_VERSION) (exceções em .trivyignore.yaml)..."
	@# Trivy via container, na versão do CI: o formato YAML de exceções (paths/expired_at) exige Trivy recente,
	@# e o trivy do brew/apt costuma ser mais velho e ignora o arquivo em silêncio.
	@docker run --rm -v /tmp/$(IMAGE_NAME).tar:/image.tar:ro -v $(CURDIR)/.trivyignore.yaml:/.trivyignore.yaml:ro \
	  -v lema-runner-trivy-cache:/root/.cache aquasec/trivy:$(TRIVY_VERSION) image --no-progress --skip-version-check \
	  --severity HIGH,CRITICAL --ignore-unfixed --vuln-type os,library --ignorefile /.trivyignore.yaml --exit-code 1 --input /image.tar; \
	  status=$$?; rm -f /tmp/$(IMAGE_NAME).tar; exit $$status
	@echo "✅ Scan concluído — nenhuma vulnerabilidade HIGH/CRITICAL encontrada."
