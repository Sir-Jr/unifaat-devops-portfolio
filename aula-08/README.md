# CI Pipeline com GitHub Actions — TechNova API (Aula 08)

[![CI Pipeline — Aula 08](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml/badge.svg)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml)

Pipeline de integração contínua para a TechNova API (Express): a cada push na `main` ou Pull Request
que altere a API, o GitHub Actions roda ESLint, testes Jest com coverage e o build da imagem Docker
com smoke test.

## Estrutura

```
.github/workflows/ci-aula08.yml   # workflow (na raiz do repositório, onde o Actions procura)
aula-08/
├── README.md                     # este arquivo
├── RESPOSTAS.md                  # questões de múltipla escolha do TA
├── screenshots/                  # evidências do pipeline
└── technova-api/
    ├── server.js                 # API (health check + pedidos)
    ├── package.json              # scripts start, test, test:ci, lint
    ├── package-lock.json         # usado pelo npm ci no CI
    ├── .eslintrc.json            # regras semi, quotes, no-unused-vars, indent...
    ├── Dockerfile                # multi-stage, usuário não-root
    ├── .dockerignore
    ├── .gitignore
    └── __tests__/server.test.js  # 9 testes (GET /health, GET/POST /api/orders)
```

## Pipeline

```
lint ──► test (Node 18 | Node 20) ──► build (Docker + smoke test) ──► comentário no PR
```

| Job | O que faz |
|-----|-----------|
| **Lint (ESLint)** | `npm ci` + `npm run lint` |
| **Tests (Jest)** | `npm run test:ci` (com `--coverage`) em Node 18 e 20; publica o relatório de coverage como artifact |
| **Build (Docker)** | confere o secret `AWS_REGION`, faz `docker build -t technova-api:<sha>`, sobe o container, consulta `/health` e remove o container |
| **Comentário no PR** | só em Pull Requests: comenta (ou atualiza) uma tabela com o resultado de cada job |

Disparo: push na `main` e Pull Request para a `main` que alterem `aula-08/technova-api/**` ou o próprio
workflow, além de execução manual (`workflow_dispatch`).

| Requisito do TF | Onde está |
|-----------------|-----------|
| R1 — multi-stage com `needs` | `lint` → `test` (`needs: lint`) → `build` (`needs: [lint, test]`) |
| R2 — ESLint | `technova-api/.eslintrc.json` + script `lint` |
| R3 — Jest | 9 testes em 2 endpoints, script `test` com `--coverage` |
| R4 — Docker build | `technova-api/Dockerfile`, imagem `technova-api:${{ github.sha }}` |
| R5 — Secret | `${{ secrets.AWS_REGION }}` no job `build` (valor fictício, mascarado no log) |
| R6 — Badge | topo deste README e do README da raiz |
| B1 — Matrix | `strategy.matrix.node-version: ['18', '20']` |
| B2 — Cache | `actions/setup-node` com `cache: 'npm'` |
| B3 — Comentário no PR | job `pr-comment` (`actions/github-script`, `pull-requests: write`) |
| B4 — Concurrency | `concurrency` com `cancel-in-progress: true` |
| B5 — Smoke test | `docker run` + `curl /health` + `docker rm -f` (roda mesmo se o teste falhar) |

## Como rodar localmente

Pré-requisitos: Node.js 18+ e Docker.

```bash
cd aula-08/technova-api
npm ci
npm run lint
npm test

docker build -t technova-api:local .
docker run -d --name technova -p 3000:3000 technova-api:local
curl http://localhost:3000/health
docker rm -f technova
```

## Secret do repositório

Configurado em **Settings → Secrets and variables → Actions** com valor fictício (nenhuma credencial real):

| Nome | Uso |
|------|-----|
| `AWS_REGION` | lido no job `build`; o GitHub mostra `***` no lugar do valor |

## Evidências

| Arquivo | Conteúdo |
|---------|----------|
| `screenshots/screenshot-pipeline-passing.png` | pipeline completo verde |
| `screenshots/screenshot-pipeline-failing.png` | pipeline falhando por erro intencional |
| `screenshots/screenshot-secrets-configured.png` | tela de secrets (nomes visíveis, valores ocultos) |
| `screenshots/screenshot-pr-comment.png` | comentário automático do CI no PR de teste #1 (bônus B3) |
