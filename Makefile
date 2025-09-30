# Makefile para ADK Web - Comandos úteis para desenvolvimento e deploy

.PHONY: help install build dev deploy-dev deploy-prod clean test

# Variáveis
PNPM := pnpm
NG := $(PNPM) exec ng
AWS := aws
BACKEND_DEV := https://agents.dev.lugui.ai
BACKEND_PROD := https://agents.lugui.ai
S3_BUCKET_DEV := adk-web-development
S3_BUCKET_PROD := adk-web-production

help: ## Mostra este menu de ajuda
	@echo "📚 Comandos disponíveis para ADK Web:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

install: ## Instala as dependências do projeto
	@echo "📦 Instalando dependências..."
	export PATH="$$HOME/.local/share/pnpm:$$PATH" && $(PNPM) install
	@echo "✅ Dependências instaladas!"

build: ## Faz o build de produção da aplicação
	@echo "🔨 Building aplicação Angular..."
	@mkdir -p src/assets/config
	@echo '{"backendUrl": "$(BACKEND_DEV)"}' > src/assets/config/runtime-config.json
	export PATH="$$HOME/.local/share/pnpm:$$PATH" && $(NG) build --configuration=production
	@echo "✅ Build concluído!"

build-prod: ## Faz o build de produção com backend de produção
	@echo "🔨 Building aplicação Angular (PRODUÇÃO)..."
	@mkdir -p src/assets/config
	@echo '{"backendUrl": "$(BACKEND_PROD)"}' > src/assets/config/runtime-config.json
	export PATH="$$HOME/.local/share/pnpm:$$PATH" && $(NG) build --configuration=production
	@echo "✅ Build de produção concluído!"

dev: ## Executa o servidor de desenvolvimento
	@echo "🚀 Iniciando servidor de desenvolvimento..."
	export PATH="$$HOME/.local/share/pnpm:$$PATH" && $(PNPM) run serve --backend=http://localhost:8000

dev-local: ## Executa com backend local
	@echo "🚀 Iniciando servidor de desenvolvimento (backend local)..."
	@mkdir -p src/assets/config
	@echo '{"backendUrl": "http://localhost:8000"}' > src/assets/config/runtime-config.json
	export PATH="$$HOME/.local/share/pnpm:$$PATH" && $(NG) serve --host 0.0.0.0 --port 4200

dev-aws: ## Executa com backend da AWS development
	@echo "🚀 Iniciando servidor de desenvolvimento (backend AWS dev)..."
	@mkdir -p src/assets/config
	@echo '{"backendUrl": "$(BACKEND_DEV)"}' > src/assets/config/runtime-config.json
	export PATH="$$HOME/.local/share/pnpm:$$PATH" && $(NG) serve --host 0.0.0.0 --port 4200

test: ## Executa os testes
	@echo "🧪 Executando testes..."
	export PATH="$$HOME/.local/share/pnpm:$$PATH" && $(NG) test --no-watch --no-progress --browsers=ChromeHeadlessCI

deploy-dev: build ## Faz deploy para development (AWS)
	@echo "☁️  Fazendo deploy para DEVELOPMENT..."
	@bash deploy.sh development
	@echo "✅ Deploy de development concluído!"

deploy-prod: build-prod ## Faz deploy para production (AWS)
	@echo "☁️  Fazendo deploy para PRODUCTION..."
	@bash deploy.sh production
	@echo "✅ Deploy de production concluído!"

sync-dev: ## Sincroniza arquivos com S3 (development) - sem build
	@echo "📤 Sincronizando com S3 (development)..."
	$(AWS) s3 sync dist/agent_framework_web/ s3://$(S3_BUCKET_DEV)/ --delete
	@echo "✅ Sincronização concluída!"

sync-prod: ## Sincroniza arquivos com S3 (production) - sem build
	@echo "📤 Sincronizando com S3 (production)..."
	$(AWS) s3 sync dist/agent_framework_web/ s3://$(S3_BUCKET_PROD)/ --delete
	@echo "✅ Sincronização concluída!"

invalidate-dev: ## Invalida cache do CloudFront (development)
	@echo "🔄 Invalidando cache do CloudFront (development)..."
	@if [ -n "$$CLOUDFRONT_DIST_ID_DEV" ]; then \
		$(AWS) cloudfront create-invalidation --distribution-id $$CLOUDFRONT_DIST_ID_DEV --paths "/*"; \
		echo "✅ Cache invalidado!"; \
	else \
		echo "❌ CLOUDFRONT_DIST_ID_DEV não configurado!"; \
		exit 1; \
	fi

invalidate-prod: ## Invalida cache do CloudFront (production)
	@echo "🔄 Invalidando cache do CloudFront (production)..."
	@if [ -n "$$CLOUDFRONT_DIST_ID_PROD" ]; then \
		$(AWS) cloudfront create-invalidation --distribution-id $$CLOUDFRONT_DIST_ID_PROD --paths "/*"; \
		echo "✅ Cache invalidado!"; \
	else \
		echo "❌ CLOUDFRONT_DIST_ID_PROD não configurado!"; \
		exit 1; \
	fi

logs-dev: ## Mostra logs do backend ECS (development)
	@echo "📋 Mostrando logs do ECS Agents (development)..."
	$(AWS) logs tail /ecs/ai-ecs-agents-development --follow

logs-prod: ## Mostra logs do backend ECS (production)
	@echo "📋 Mostrando logs do ECS Agents (production)..."
	$(AWS) logs tail /ecs/ai-ecs-agents-production --follow

status-dev: ## Verifica status do deploy (development)
	@echo "📊 Status do ADK Web (Development):"
	@echo ""
	@echo "🌐 URL: https://adk.dev.lugui.ai"
	@echo "📦 Bucket S3:"
	@$(AWS) s3 ls s3://$(S3_BUCKET_DEV)/ | head -5
	@echo ""
	@echo "🔗 Backend: $(BACKEND_DEV)"
	@curl -s -I $(BACKEND_DEV)/docs | head -1
	@echo ""
	@echo "✅ Frontend:"
	@curl -s -I https://adk.dev.lugui.ai | head -1

status-prod: ## Verifica status do deploy (production)
	@echo "📊 Status do ADK Web (Production):"
	@echo ""
	@echo "🌐 URL: https://adk.lugui.ai"
	@echo "📦 Bucket S3:"
	@$(AWS) s3 ls s3://$(S3_BUCKET_PROD)/ | head -5
	@echo ""
	@echo "🔗 Backend: $(BACKEND_PROD)"
	@curl -s -I $(BACKEND_PROD)/docs | head -1
	@echo ""
	@echo "✅ Frontend:"
	@curl -s -I https://adk.lugui.ai | head -1

clean: ## Remove arquivos de build
	@echo "🧹 Limpando arquivos de build..."
	rm -rf dist/
	rm -rf .angular/
	rm -rf node_modules/.cache/
	@echo "✅ Limpeza concluída!"

terraform-plan: ## Mostra mudanças no Terraform (development)
	@echo "📋 Planejando mudanças no Terraform..."
	cd ../lugui-api-infra && terraform plan -var-file="environments/local.development.tfvars" -target=aws_s3_bucket.adk_web -target=aws_cloudfront_distribution.adk_web

terraform-apply: ## Aplica infraestrutura no Terraform (development)
	@echo "🏗️  Aplicando infraestrutura..."
	cd ../lugui-api-infra && terraform apply -var-file="environments/local.development.tfvars" -target=aws_s3_bucket.adk_web -target=aws_cloudfront_distribution.adk_web

info: ## Mostra informações de configuração
	@echo "ℹ️  Informações de Configuração:"
	@echo ""
	@echo "📂 Diretórios:"
	@echo "   - Source: src/"
	@echo "   - Build output: dist/agent_framework_web/"
	@echo ""
	@echo "🌍 Ambientes:"
	@echo "   - Development: https://adk.dev.lugui.ai"
	@echo "   - Production: https://adk.lugui.ai"
	@echo ""
	@echo "🔗 Backend APIs:"
	@echo "   - Development: $(BACKEND_DEV)"
	@echo "   - Production: $(BACKEND_PROD)"
	@echo ""
	@echo "📦 S3 Buckets:"
	@echo "   - Development: s3://$(S3_BUCKET_DEV)"
	@echo "   - Production: s3://$(S3_BUCKET_PROD)"
	@echo ""
	@if [ -n "$$CLOUDFRONT_DIST_ID_DEV" ]; then \
		echo "☁️  CloudFront Dev: $$CLOUDFRONT_DIST_ID_DEV"; \
	else \
		echo "⚠️  CloudFront Dev: Não configurado (export CLOUDFRONT_DIST_ID_DEV)"; \
	fi
	@if [ -n "$$CLOUDFRONT_DIST_ID_PROD" ]; then \
		echo "☁️  CloudFront Prod: $$CLOUDFRONT_DIST_ID_PROD"; \
	else \
		echo "⚠️  CloudFront Prod: Não configurado (export CLOUDFRONT_DIST_ID_PROD)"; \
	fi

.DEFAULT_GOAL := help
