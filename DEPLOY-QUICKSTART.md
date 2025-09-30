# 🚀 Quick Start - Deploy ADK Web na AWS

## 📋 Checklist Rápido

### 1️⃣ Provisionar Infraestrutura (Uma única vez)

```bash
cd ../lugui-api-infra

# Selecionar workspace
terraform workspace select development

# Aplicar infraestrutura
terraform apply -var-file="environments/local.development.tfvars"

# Salvar o CloudFront Distribution ID
terraform output adk_web_cloudfront_distribution_id
# Exemplo: E1ABC2DEF3GHIJ
```

### 2️⃣ Configurar Variáveis de Ambiente

```bash
# Adicionar ao seu ~/.bashrc ou ~/.zshrc
export CLOUDFRONT_DIST_ID_DEV="E1ABC2DEF3GHIJ"  # Do output acima
export CLOUDFRONT_DIST_ID_PROD="E9XYZ8WVU7TSRQ" # Para produção
```

### 3️⃣ Deploy Manual

```bash
cd adk-web

# Deploy para development
./deploy.sh development

# Deploy para production
./deploy.sh production
```

**Pronto!** 🎉

O ADK Web estará disponível em:
- Development: https://adk.dev.lugui.ai
- Production: https://adk.lugui.ai

---

## 🔄 Deploy Automático (GitHub Actions)

### Configurar Secrets no GitHub

No repositório do GitHub, adicione em `Settings → Secrets and variables → Actions`:

```
AWS_ACCESS_KEY_ID: AKIA...
AWS_SECRET_ACCESS_KEY: ...
CLOUDFRONT_DISTRIBUTION_ID_DEV: E1ABC2DEF3GHIJ
CLOUDFRONT_DISTRIBUTION_ID_PROD: E9XYZ8WVU7TSRQ
```

### Fazer Push

```bash
git add .
git commit -m "feat: adiciona infraestrutura ADK Web"
git push origin development  # Deploy automático!
```

---

## 🏗️ Arquivos Terraform Criados

### `/lugui-api-infra/adk-web.tf`
- S3 Bucket para arquivos estáticos
- CloudFront Distribution
- Route 53 DNS record
- Políticas de acesso

### Variáveis Adicionadas

Em `variables.tf`:
```hcl
variable "adk_web_domain" {
  description = "Domain for the ADK Web UI"
  type        = string
}
```

Em `local.development.tfvars`:
```hcl
adk_web_domain = "adk.dev.lugui.ai"
```

Em `local.production.tfvars`:
```hcl
adk_web_domain = "adk.lugui.ai"
```

---

## 🔍 Verificação Rápida

```bash
# 1. Verificar arquivos no S3
aws s3 ls s3://adk-web-development/

# 2. Testar acesso
curl -I https://adk.dev.lugui.ai

# 3. Verificar backend configurado
curl https://adk.dev.lugui.ai/assets/config/runtime-config.json
# Deve retornar: {"backendUrl": "https://agents.dev.lugui.ai"}

# 4. Testar listagem de agentes
curl https://adk.dev.lugui.ai/list-apps?relative_path=./
```

---

## 🎯 Endpoints Importantes

### Frontend (Servido pelo S3/CloudFront)
- `https://adk.dev.lugui.ai/` - UI do ADK Web

### Backend (Proxy para ECS via CloudFront)
- `https://adk.dev.lugui.ai/list-apps` - Lista agentes
- `https://adk.dev.lugui.ai/run_sse` - Executa agente (SSE)
- `https://adk.dev.lugui.ai/apps/{app}/users/{user}/sessions/{session}` - Sessões
- `https://adk.dev.lugui.ai/debug/trace/{id}` - Trace debugging

---

## ⚙️ Configuração do Backend (ECS)

O serviço `ai-ecs-agents` já está configurado para aceitar requisições do ADK Web:

```python
# ai-ecs-agents/main.py
app = get_fast_api_app(
    agents_dir="src/agents",
    session_service_uri=SESSION_DB_URL,
    allow_origins=["*"],  # ✅ Já configurado
    web=True,              # ✅ ADK Web habilitado
    port=8000,
    # ...
)
```

**Nota**: Em produção, considere restringir `allow_origins` para:
```python
allow_origins=[
    "https://adk.dev.lugui.ai",
    "https://adk.lugui.ai"
]
```

---

## 📊 Recursos Terraform Criados

Ao executar `terraform apply`, os seguintes recursos são criados:

1. **aws_s3_bucket.adk_web** - Bucket para arquivos
2. **aws_s3_bucket_policy.adk_web** - Política de acesso
3. **aws_cloudfront_distribution.adk_web** - CDN global
4. **aws_cloudfront_origin_access_control.adk_web** - Controle de acesso
5. **aws_route53_record.adk_web_lugui_ai** - DNS record

**Outputs disponíveis**:
```bash
terraform output adk_web_url
terraform output adk_web_bucket_name
terraform output adk_web_cloudfront_domain_name
terraform output adk_web_cloudfront_distribution_id
```

---

## 🔐 Segurança

- ✅ S3 Bucket privado (sem acesso público)
- ✅ HTTPS obrigatório
- ✅ TLS 1.2+
- ✅ Origin Access Control (OAC)
- ✅ Certificado SSL gerenciado
- ✅ Headers de segurança

---

## 🆘 Troubleshooting

### Problema: "Access Denied" no S3
```bash
# Reaplicar a política do bucket
terraform apply -target=aws_s3_bucket_policy.adk_web
```

### Problema: Cache antigo no CloudFront
```bash
# Invalidar cache manualmente
aws cloudfront create-invalidation \
  --distribution-id E1ABC2DEF3GHIJ \
  --paths "/*"
```

### Problema: Backend não responde
```bash
# Verificar se o ECS está rodando
aws ecs describe-services \
  --cluster lugui-agents \
  --services ai-ecs-agents-development

# Ver logs
aws logs tail /ecs/ai-ecs-agents-development --follow
```

---

## 📚 Documentação Completa

Para detalhes completos, consulte:
- **DEPLOY.md** - Documentação detalhada de deploy
- **ARQUITETURA-AWS.md** - Arquitetura completa (este arquivo)
- **README.md** - Documentação do projeto ADK Web

---

**🎉 Agora você tem o ADK Web rodando na AWS com infraestrutura profissional!**
