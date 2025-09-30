#!/bin/bash

# Script de deploy do ADK Web para AWS S3 + CloudFront
# Uso: ./deploy.sh [development|production]

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Verificar se o ambiente foi passado
if [ -z "$1" ]; then
    echo -e "${RED}❌ Erro: Especifique o ambiente (development ou production)${NC}"
    echo "Uso: ./deploy.sh [development|production]"
    exit 1
fi

ENVIRONMENT=$1

# Configurar variáveis baseadas no ambiente
if [ "$ENVIRONMENT" == "production" ]; then
    BACKEND_URL="https://agents.lugui.ai"
    S3_BUCKET="adk-web-production"
    CLOUDFRONT_DISTRIBUTION_ID="${CLOUDFRONT_DIST_ID_PROD:-CONFIGURE_ME}"
    DOMAIN="adk.lugui.ai"
elif [ "$ENVIRONMENT" == "development" ]; then
    BACKEND_URL="https://agents.dev.lugui.ai"
    S3_BUCKET="adk-web-development"
    CLOUDFRONT_DISTRIBUTION_ID="${CLOUDFRONT_DIST_ID_DEV:-CONFIGURE_ME}"
    DOMAIN="adk.dev.lugui.ai"
else
    echo -e "${RED}❌ Ambiente inválido. Use 'development' ou 'production'${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Iniciando deploy do ADK Web${NC}"
echo -e "${BLUE}📦 Ambiente: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}🔗 Backend: ${BACKEND_URL}${NC}"
echo -e "${BLUE}🪣 Bucket S3: ${S3_BUCKET}${NC}"
echo ""

# 1. Criar arquivo de configuração do runtime
echo -e "${GREEN}📝 Criando runtime-config.json...${NC}"
mkdir -p src/assets/config
echo "{\"backendUrl\": \"${BACKEND_URL}\"}" > src/assets/config/runtime-config.json
cat src/assets/config/runtime-config.json
echo ""

# 2. Instalar dependências se necessário
if [ ! -d "node_modules" ]; then
    echo -e "${GREEN}📦 Instalando dependências...${NC}"
    export PATH="$HOME/.local/share/pnpm:$PATH"
    pnpm install
    echo ""
fi

# 3. Build da aplicação
echo -e "${GREEN}🔨 Building aplicação Angular...${NC}"
export PATH="$HOME/.local/share/pnpm:$PATH"
pnpm exec ng build --configuration=production
echo ""

# 4. Upload para S3
echo -e "${GREEN}☁️  Fazendo upload para S3...${NC}"

# Verificar qual estrutura de diretório foi gerada
if [ -d "dist/agent_framework_web/browser" ]; then
    BUILD_DIR="dist/agent_framework_web/browser"
    echo -e "${BLUE}📂 Usando estrutura: browser/${NC}"
else
    BUILD_DIR="dist/agent_framework_web"
    echo -e "${BLUE}📂 Usando estrutura: raiz${NC}"
fi

# Sync de todos os arquivos com cache longo (exceto index.html)
aws s3 sync ${BUILD_DIR}/ s3://${S3_BUCKET}/ \
    --delete \
    --cache-control "public,max-age=31536000,immutable" \
    --exclude "index.html" \
    --exclude "assets/config/runtime-config.json"

# Upload do index.html sem cache
aws s3 cp ${BUILD_DIR}/index.html s3://${S3_BUCKET}/index.html \
    --cache-control "no-cache,no-store,must-revalidate" \
    --content-type "text/html"

# Upload do runtime-config.json sem cache
aws s3 cp ${BUILD_DIR}/assets/config/runtime-config.json s3://${S3_BUCKET}/assets/config/runtime-config.json \
    --cache-control "no-cache,no-store,must-revalidate" \
    --content-type "application/json"

echo ""

# 5. Invalidar cache do CloudFront
if [ "$CLOUDFRONT_DISTRIBUTION_ID" != "CONFIGURE_ME" ]; then
    echo -e "${GREEN}🔄 Invalidando cache do CloudFront...${NC}"
    INVALIDATION_ID=$(aws cloudfront create-invalidation \
        --distribution-id ${CLOUDFRONT_DISTRIBUTION_ID} \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text)
    
    echo -e "${BLUE}📋 ID da invalidação: ${INVALIDATION_ID}${NC}"
    echo ""
else
    echo -e "${RED}⚠️  CLOUDFRONT_DISTRIBUTION_ID não configurado. Pule a invalidação do cache.${NC}"
    echo ""
fi

# 6. Resumo final
echo -e "${GREEN}✅ Deploy concluído com sucesso!${NC}"
echo ""
echo -e "${BLUE}📊 Resumo do Deploy:${NC}"
echo -e "   🌍 Ambiente: ${ENVIRONMENT}"
echo -e "   🪣 Bucket S3: ${S3_BUCKET}"
echo -e "   🔗 Backend URL: ${BACKEND_URL}"
echo -e "   🌐 URL do ADK Web: https://${DOMAIN}"
echo ""
echo -e "${GREEN}🎉 ADK Web está pronto para uso!${NC}"
