# Arquitetura AWS - ADK Web UI

## 📐 Visão Geral da Infraestrutura

```
Internet
    │
    ▼
┌───────────────────────────────────────────────────────┐
│              Route 53 DNS                             │
│  adk.dev.lugui.ai → CloudFront Distribution          │
└────────────────────┬──────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              CloudFront (CDN Global)                    │
│  - Cache de arquivos estáticos                          │
│  - SSL/TLS Termination                                  │
│  - Compressão GZIP                                      │
│  - Roteamento inteligente                               │
└────────┬──────────────────────────┬─────────────────────┘
         │                          │
         │ (Estático)               │ (API Calls)
         ▼                          ▼
┌──────────────────┐      ┌────────────────────────────┐
│   S3 Bucket      │      │  Application Load Balancer │
│  adk-web-dev     │      │  agents.dev.lugui.ai       │
│                  │      │  (Internal ALB)            │
│  - index.html    │      └──────────┬─────────────────┘
│  - main.js       │                 │
│  - styles.css    │                 ▼
│  - assets/       │      ┌────────────────────────────┐
└──────────────────┘      │  ECS Fargate Service       │
                          │  ai-ecs-agents-development │
                          │                            │
                          │  Container:                │
                          │  - Python 3.12             │
                          │  - google-adk              │
                          │  - FastAPI                 │
                          │  - Port: 8000              │
                          └──────────┬─────────────────┘
                                     │
                                     ▼
                          ┌──────────────────────────┐
                          │   Aurora PostgreSQL      │
                          │   (Session Storage)      │
                          │   Schema: adk-agents     │
                          └──────────────────────────┘
```

## 🗂️ Componentes da Infraestrutura

### 1. S3 Bucket (`adk-web-{environment}`)

**Finalidade**: Armazenar os arquivos estáticos compilados do Angular

**Configuração**:
- **Public Access**: Totalmente bloqueado
- **Acesso**: Apenas via CloudFront (usando OAC)
- **Versioning**: Desabilitado (opcional habilitar)
- **Encryption**: Padrão S3 (AES-256)

**Estrutura de arquivos**:
```
adk-web-development/
├── index.html                    # [No-Cache]
├── main.{hash}.js               # [Cache: 1 ano]
├── polyfills.{hash}.js          # [Cache: 1 ano]
├── styles.{hash}.css            # [Cache: 1 ano]
└── assets/
    ├── config/
    │   └── runtime-config.json  # [No-Cache] ← Backend URL
    ├── ADK-512-color.svg
    └── audio-processor.js
```

### 2. CloudFront Distribution

**Finalidade**: Distribuir o conteúdo globalmente e rotear chamadas de API

**Origins**:
1. **S3 Origin**: Arquivos estáticos (HTML, JS, CSS)
   - Origin ID: `S3-adk-web-{env}`
   - Acesso: Via OAC (Origin Access Control)

2. **ALB Origin**: Backend API (ADK API Server)
   - Origin ID: `ADK-API-Backend`
   - Domain: `agents.dev.lugui.ai`
   - Protocol: HTTPS only

**Cache Behaviors**:

| Path Pattern | Target Origin | Cache | Descrição |
|--------------|---------------|-------|-----------|
| `/*` (default) | S3 | Sim (1h) | Arquivos estáticos |
| `/apps/*` | ALB | Não | Endpoints ADK API |
| `/debug/*` | ALB | Não | Debug/Trace |
| `/list-apps*` | ALB | Não | Listar agentes |
| `/run_sse*` | ALB | Não | Server-Sent Events |
| `/run_live*` | ALB | Não | WebSocket |

**SSL/TLS**:
- Certificado: `aws_acm_certificate.lugui_ai_cert`
- Protocolo mínimo: TLSv1.2
- SNI: Habilitado

### 3. Route 53

**Finalidade**: DNS management

**Registros criados**:
```
adk.dev.lugui.ai  → CloudFront Distribution (Alias A)
adk.lugui.ai      → CloudFront Distribution (Alias A)
```

### 4. ECS Service (Backend)

**Service**: `ai-ecs-agents-{environment}`

**Configuração**:
- **Cluster**: `lugui-agents`
- **Launch Type**: EC2
- **CPU**: 4096 (4 vCPU)
- **Memory**: 8192 MB (8 GB)
- **Port**: 8000
- **Health Check**: `/docs`

**Variáveis de Ambiente Relevantes**:
```bash
SESSION_DB_URL=postgresql://user:pass@aurora/LuguiAPI?search_path=adk-agents
AGENT_DIR=src/agents
WORKSPACE=development
```

**CORS Configuration** (já configurado no `main.py`):
```python
allow_origins=["*"]  # Em produção, restringir para domínios específicos
```

## 🔄 Fluxo de Requisições

### 1. Requisição de Arquivo Estático
```
Usuário → CloudFront → S3 Bucket → CloudFront (Cache) → Usuário
```

### 2. Requisição de API
```
Usuário → CloudFront → ALB → ECS (ADK API Server) → Aurora → ECS → ALB → CloudFront → Usuário
```

### 3. Server-Sent Events (SSE)
```
Usuário → CloudFront (pass-through) → ALB → ECS (streaming) → ... → Usuário
```

**Importante**: CloudFront passa SSE sem cache, mantendo a conexão aberta.

### 4. WebSocket (run_live)
```
Usuário → CloudFront → ALB → ECS (websocket) ⟷ Usuário
```

**Limitação**: CloudFront tem timeout de 10 min para WebSocket. Para sessões longas, considere ALB direto.

## 🔧 Configurações Especiais

### Timeout para SSE

O ALB está configurado com `idle_timeout = 900s` (15 minutos) para suportar Server-Sent Events de longa duração.

### Base Path no Build

O Angular é buildado com:
```json
"baseHref": "./",
"deployUrl": "./"
```

Isso permite que a aplicação funcione tanto em:
- Raiz do domínio: `https://adk.dev.lugui.ai/`
- Subpaths (se necessário): `https://adk.dev.lugui.ai/dev-ui/`

## 📊 Monitoramento

### CloudWatch Logs

Os logs do ECS ficam em:
```
/ecs/ai-ecs-agents-development
```

### Métricas Importantes

- **CloudFront**: Requests, Bytes Downloaded, Error Rate
- **ECS**: CPU Utilization, Memory Utilization, Task Count
- **ALB**: Request Count, Target Response Time, HTTP 5xx

## 💰 Estimativa de Custos

**Ambiente Development** (uso moderado):

| Serviço | Custo Mensal Estimado |
|---------|----------------------|
| S3 Storage (1 GB) | ~$0.02 |
| CloudFront (10 GB/mês) | ~$1.00 |
| Route 53 (Hosted Zone) | Compartilhado |
| ECS (já existe) | Compartilhado |
| ALB (já existe) | Compartilhado |
| **Total Incremental** | **~$1.02/mês** |

**Nota**: O custo incremental é muito baixo porque reutilizamos a infraestrutura existente (ECS, ALB, Aurora).

## 🚦 Estado Atual vs Futuro

### ✅ Implementado
- [x] S3 Bucket para hospedagem
- [x] CloudFront com domínio personalizado
- [x] SSL/TLS via ACM
- [x] Roteamento DNS via Route 53
- [x] Cache behaviors para API
- [x] OAC (Origin Access Control)
- [x] GitHub Actions para CI/CD
- [x] Script de deploy manual

### 🔮 Próximos Passos (Opcional)
- [ ] CloudWatch Dashboard específico para ADK Web
- [ ] Alarmes para taxa de erro
- [ ] WAF (Web Application Firewall)
- [ ] Ambiente de staging separado
- [ ] Blue/Green deployment
- [ ] Feature flags via Parameter Store

## 📞 Suporte

Para dúvidas ou problemas com o deploy:
- Verificar logs do CloudWatch
- Consultar documentação do ADK
- Validar variáveis de ambiente no Terraform
