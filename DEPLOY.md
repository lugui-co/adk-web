# Deploy do ADK Web na AWS

Este documento descreve como fazer o deploy do ADK Web (Agent Development Kit Web UI) na AWS usando S3 + CloudFront.

## 🏗️ Arquitetura

O ADK Web é servido como uma aplicação Angular estática com a seguinte arquitetura:

```
┌─────────────┐
│   Usuário   │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│    CloudFront       │ (CDN Global)
│  adk.dev.lugui.ai   │
└──────┬──────────────┘
       │
       ├──────────────────┐
       │                  │
       ▼                  ▼
┌──────────────┐   ┌─────────────────┐
│   S3 Bucket  │   │  ALB (Agents)   │
│  (Estático)  │   │  Backend API    │
│  HTML/JS/CSS │   │  agents.dev.*   │
└──────────────┘   └─────────────────┘
                           │
                           ▼
                   ┌───────────────────┐
                   │   ECS (Fargate)   │
                   │  ADK API Server   │
                   │ google-adk-python │
                   └───────────────────┘
```

## 📋 Pré-requisitos

1. **AWS CLI** configurado com credenciais válidas
2. **Node.js** e **pnpm** instalados
3. **Terraform** para provisionar a infraestrutura
4. **CloudFront Distribution ID** (será criado pelo Terraform)

## 🚀 Deploy Inicial (Primeira vez)

### 1. Provisionar a Infraestrutura com Terraform

```bash
cd lugui-api-infra

# Selecionar o workspace
terraform workspace select development  # ou production

# Aplicar a infraestrutura
terraform apply -var-file="environments/local.development.tfvars"

# Anotar o CloudFront Distribution ID do output
terraform output adk_web_cloudfront_distribution_id
```

Isso criará:
- ✅ S3 Bucket: `adk-web-development` ou `adk-web-production`
- ✅ CloudFront Distribution com domínio personalizado
- ✅ Registro DNS: `adk.dev.lugui.ai` ou `adk.lugui.ai`
- ✅ Certificado SSL (via ACM)
- ✅ Políticas de acesso S3 ↔ CloudFront

### 2. Configurar Secrets no GitHub (para CI/CD)

Adicione os seguintes secrets no repositório:

- `AWS_ACCESS_KEY_ID`: Chave de acesso AWS
- `AWS_SECRET_ACCESS_KEY`: Secret key AWS
- `CLOUDFRONT_DISTRIBUTION_ID_DEV`: ID da distribuição de desenvolvimento
- `CLOUDFRONT_DISTRIBUTION_ID_PROD`: ID da distribuição de produção

### 3. Deploy Manual (Opcional)

Se preferir fazer deploy manual em vez de usar GitHub Actions:

```bash
cd adk-web

# Para development
./deploy.sh development

# Para production
./deploy.sh production
```

**Nota**: Configure as variáveis de ambiente antes:
```bash
export CLOUDFRONT_DIST_ID_DEV="E2OB3FUY0KFLTU"
export CLOUDFRONT_DIST_ID_PROD="E3SQPPMQPUTRAN"
```

## 🔄 Deploy Automático (CI/CD)

O deploy automático acontece via GitHub Actions quando você faz push para:

- `development` → Deploy para `adk.dev.lugui.ai`
- `production` → Deploy para `adk.lugui.ai`

O workflow está em: `.github/workflows/deploy-aws.yml`

## 🔧 Configuração do Backend

O ADK Web se conecta ao backend através do arquivo `runtime-config.json`, que é gerado dinamicamente durante o build.

### URLs do Backend por Ambiente:

- **Development**: `https://agents.dev.lugui.ai`
- **Production**: `https://agents.lugui.ai`

### Endpoints Principais:

- `/list-apps` - Lista os agentes disponíveis
- `/run_sse` - Executa agentes com Server-Sent Events
- `/run_live` - WebSocket para streaming bidirecional
- `/apps/{app}/users/{user}/sessions/{session}` - Gerenciamento de sessões
- `/debug/trace/{id}` - Informações de trace/debug

## 📝 Estrutura dos Arquivos de Deploy

```
adk-web/
├── .github/
│   └── workflows/
│       ├── angular-tests.yml       # Testes automatizados
│       └── deploy-aws.yml          # Deploy para AWS (NOVO)
├── src/
│   └── assets/
│       └── config/
│           └── runtime-config.json # Configuração do backend
├── deploy.sh                        # Script de deploy manual (NOVO)
├── DEPLOY.md                        # Este arquivo (NOVO)
└── package.json
```

## 🌐 URLs de Acesso

Após o deploy, o ADK Web estará disponível em:

- **Development**: https://adk.dev.lugui.ai
- **Production**: https://adk.lugui.ai

## 🔍 Verificação do Deploy

Para verificar se o deploy foi bem-sucedido:

```bash
# 1. Verificar se os arquivos estão no S3
aws s3 ls s3://adk-web-development/

# 2. Testar a URL
curl -I https://adk.dev.lugui.ai

# 3. Verificar o runtime-config.json
curl https://adk.dev.lugui.ai/assets/config/runtime-config.json
```

Resposta esperada do `runtime-config.json`:
```json
{"backendUrl": "https://agents.dev.lugui.ai"}
```

## 🐛 Troubleshooting

### Problema: CloudFront retorna 403

**Solução**: Verifique se a política do S3 bucket permite acesso do CloudFront:
```bash
terraform apply -var-file="environments/local.development.tfvars" -target=aws_s3_bucket_policy.adk_web
```

### Problema: Backend URL incorreta

**Solução**: Verifique o `runtime-config.json` e refaça o build:
```bash
pnpm exec ng build --configuration=production
```

### Problema: Erro 404 em rotas do Angular

**Solução**: Verifique se os `custom_error_response` estão configurados no CloudFront para redirecionar 403/404 para `/index.html`.

## 📚 Recursos Adicionais

- [Documentação do ADK](https://google.github.io/adk-docs/)
- [AWS CloudFront Docs](https://docs.aws.amazon.com/cloudfront/)
- [Angular Deployment Guide](https://angular.dev/tools/cli/deployment)

## 💡 Notas Importantes

1. **CORS**: O backend (ECS Agents) deve aceitar requisições de `https://adk.dev.lugui.ai` e `https://adk.lugui.ai`
2. **WebSocket**: CloudFront não suporta WebSocket por padrão. Para `run_live`, pode ser necessário configuração adicional ou usar ALB direto
3. **Cache**: O `index.html` e `runtime-config.json` não têm cache para permitir atualizações rápidas
4. **SSL**: O certificado é compartilhado (`lugui_ai_cert`) entre todos os serviços
5. **Custo**: CloudFront PriceClass_100 (apenas NA e EU) para otimizar custos

## 🔐 Segurança

- ✅ S3 Bucket com acesso público bloqueado
- ✅ Acesso ao S3 apenas via CloudFront (OAC)
- ✅ HTTPS obrigatório (redirect-to-https)
- ✅ TLS 1.2+ apenas
- ✅ Certificado SSL gerenciado pelo ACM

---

**Autor**: Time Lugui  
**Última atualização**: 30/09/2025
