# Docker Registry (Amazon ECR) e AI Review — TechNova API (Aula 09)

[![CI — Aula 09 (ECR)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ci.yml/badge.svg)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ci.yml)
[![AI Code Review](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ai-review.yml/badge.svg)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ai-review.yml)
[![Security Scan](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/security-scan.yml/badge.svg)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/security-scan.yml)

A imagem da TechNova API é buildada uma vez, publicada no **Amazon ECR** do AWS Academy Learner Lab
(`us-east-1`) com tags `sha-…`, `latest` e semver, e cada Pull Request passa por um **AI review**
automático com quality gate.

## Estrutura

```
.github/                           # na raiz do repositório (único lugar onde o Actions procura)
├── workflows/
│   ├── ci.yml                     # lint -> test -> build-and-push (ECR via amazon-ecr-login)
│   ├── ai-review.yml              # AI review em PRs + quality gate
│   └── security-scan.yml          # scan de segurança dedicado (bônus)
└── scripts/
    └── ai-review.js               # script de análise (18 padrões)
aula-09/
├── ecr-push.sh                    # script principal: repo, login, build, tags e push no ECR
├── ecr-rollback.sh                # pull de uma tag do ECR + deploy local + /health
├── ecr-lifecycle-policy.json      # lifecycle policy do repositório (bônus)
├── ia-cicd-analise.md             # análise da estratégia
├── evidencias/                    # saídas reais (ID da conta mascarado): push v1.0.0, rollback, scan
├── screenshots/                   # prints do console ECR, AI review, push e quality gate
└── technova-api/
    ├── Dockerfile                 # multi-stage, labels OCI, usuário não-root, HEALTHCHECK
    ├── .dockerignore
    ├── server.js, package.json, package-lock.json, .eslintrc.json
    └── __tests__/server.test.js
```

O TF mostra `.github/` dentro de `aula-09/`, mas o GitHub Actions só executa workflows de
`.github/workflows/` na raiz do repositório (o mesmo arranjo da Aula 08). O `Dockerfile` e o
`.dockerignore` ficam em `technova-api/`, junto da aplicação, como no laboratório.

| Requisito do TF | Onde está |
|-----------------|-----------|
| Repositório ECR `technova-api` (idempotente) | `ecr-push.sh` — `describe-repositories` ou `create-repository` |
| Login no ECR | `ecr-push.sh` — `aws ecr get-login-password \| docker login --username AWS` |
| Build multi-stage | `technova-api/Dockerfile` (`builder` + `runtime`) |
| Tags `sha-XXXXXXX`, `latest`, semver | `ecr-push.sh` — semver `X.Y.Z`, `X.Y`, `X` a partir da git tag `vX.Y.Z` |
| Pull + rollback por tag | `ecr-rollback.sh <tag>` |
| CI com push no ECR (opcional) | `.github/workflows/ci.yml` — `configure-aws-credentials@v4` + `amazon-ecr-login@v2`, push só fora de PR |
| AI review em PR | `.github/workflows/ai-review.yml` — `pull_request` (opened, synchronize, reopened) |
| Comentário em tabela por severidade | `ai-review.js` → `actions/github-script` |
| Quality gate | step *Quality gate*: CRITICAL → `exit 1`; check `ai-review` obrigatório na `main` |
| Documentação | `ia-cicd-analise.md` |
| Bônus: lifecycle policy | `ecr-lifecycle-policy.json`, aplicada pelo `ecr-push.sh` |
| Bônus: scan on push | `ecr-push.sh` — `scanOnPush=true`; resultado em `evidencias/ecr-scan.txt` (26 achados no openssl/zlib do Alpine → 0 após `apk upgrade`) |
| Bônus: comentário atualizado | marcador `<!-- ai-review-technova -->` + `updateComment` |
| Bônus: security scan separado | `.github/workflows/security-scan.yml` |
| Bônus: badges | topo deste README |
| Bônus: mais de 8 padrões | 18 padrões (ver `ia-cicd-analise.md`) |

## Como executar

Pré-requisitos: Docker, Node.js 18+, Git e AWS CLI v2 com as credenciais da sessão do Learner Lab em
`~/.aws/credentials` (incluindo `aws_session_token`).

```bash
export AWS_DEFAULT_REGION=us-east-1
aws sts get-caller-identity          # confere se a sessão do Lab está ativa

# Build e push (sha + latest; semver se o commit tiver tag vX.Y.Z)
./aula-09/ecr-push.sh

# Release
git tag v1.0.0 -m "Release 1.0.0"
./aula-09/ecr-push.sh                # publica também 1.0.0, 1.0 e 1
git push origin v1.0.0               # dispara o ci.yml para a tag

# Pull e rollback por tag
./aula-09/ecr-rollback.sh latest
./aula-09/ecr-rollback.sh 1.0.0
```

O ID da conta aparece mascarado (`************`) na saída dos scripts e nos logs do CI.

### Testes locais da aplicação

```bash
cd aula-09/technova-api
npm ci
npm run lint
npm test
docker build -t technova-api:local . && docker run -p 3000:3000 technova-api:local
curl http://localhost:3000/health
```

### Testar o AI review sem abrir PR

```bash
git diff main...HEAD > /tmp/pr-diff.txt
node .github/scripts/ai-review.js     # relatório em /tmp/ai-review-result.md
```

### CI com push no ECR

Cadastrar em **Settings → Secrets and variables → Actions** os valores da sessão atual do Lab:
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_SESSION_TOKEN`. Eles expiram com a sessão; sem os
secrets, o job builda e testa a imagem e pula o push com um aviso.
