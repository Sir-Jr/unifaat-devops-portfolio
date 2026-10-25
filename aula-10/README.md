# Terraform GitOps + Pipeline de CD — TechNova API (Aula 10)

[![CD Pipeline](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/cd.yml/badge.svg)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/cd.yml)
[![Terraform Apply](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/terraform-apply.yml/badge.svg)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/terraform-apply.yml)

Nenhum humano roda Terraform nem faz deploy à mão (a exceção é o rollback de emergência, documentado no runbook):

- **Infra (GitOps):** PR com `.tf` → `terraform-plan.yml` comenta o plan → merge → `terraform-apply.yml`.
- **Aplicação (CD):** push na `main` → lint → test → build+push no Amazon ECR → deploy Recreate via SSH
  na EC2 → health check.

Tudo no AWS Academy Learner Lab (`us-east-1`), autenticado com as credenciais temporárias da sessão.

## Estrutura

```
.github/workflows/                 # na raiz do repositório (único lugar onde o Actions procura)
├── terraform-plan.yml             # plan em PRs + comentário (fmt, validate, guard de destroy)
├── terraform-apply.yml            # apply no merge para a main
├── terraform-destroy.yml          # bônus: destroy manual com aprovação (environment "destroy")
├── cd.yml                         # lint → test → build-push (ECR) → deploy → health check
└── aws-check.yml                  # teste das credenciais do Lab (workflow_dispatch)
aula-10/
├── terraform/
│   ├── provider.tf                # provider AWS + backend S3 (lock nativo)
│   ├── main.tf                    # security group, key pair, EC2 (Docker + AWS CLI)
│   ├── variables.tf
│   ├── outputs.tf
│   ├── user_data.sh.tftpl         # prepara a EC2 para receber deploys
│   ├── technova-deploy.pub        # chave pública do deploy (a privada é o secret EC2_SSH_KEY)
│   └── bootstrap-backend.sh       # cria o bucket do state (uma vez, antes do 1º init)
├── technova-api/                  # aplicação (Node 22) + Dockerfile multi-stage
├── rollback.sh                    # rollback para uma tag sha-* do ECR
├── docs/runbook-rollback.md       # procedimento de rollback
├── gitops-cd-analise.md           # documentação e análise
├── evidencias/                    # saídas reais (ID da conta e IP mascarados)
└── screenshots/
```

O TF mostra `.github/` dentro de `aula-10/`, mas o GitHub Actions só executa workflows da raiz do
repositório (mesmo arranjo das Aulas 08 e 09). O `Dockerfile` fica em `technova-api/`, que é o context do
build.

| Requisito do TF | Onde está |
|-----------------|-----------|
| Plan em PR (só com `.tf`/`.tfvars`), comentário formatado, falha se o plan falhar | `terraform-plan.yml` |
| Apply no push para a `main` (só com `.tf`/`.tfvars`), output no log | `terraform-apply.yml` |
| Auth com as 3 credenciais de sessão + nota sobre OIDC | `configure-aws-credentials@v4` nos workflows; §2 do `gitops-cd-analise.md` |
| CD lint → test → build-push (ECR, sha + latest) → deploy | `cd.yml` (`amazon-ecr-login@v2`, context `aula-10/technova-api/`) |
| Deploy Recreate via SSH com login no ECR antes do pull | job `deploy`: `appleboy/ssh-action` → login → stop → rm → pull → run |
| Health check com retry, falha se não responder | step *Health check* (20 tentativas, `exit 1`) |
| Documentação | `gitops-cd-analise.md` |
| Runbook de rollback testado | `docs/runbook-rollback.md` + `rollback.sh` + `evidencias/rollback-teste.txt` |
| Bônus: plan com destroy exige aprovação extra | rótulo `aprovado-destroy` (testado no PR #5) |
| Bônus: comentário atualizado, não duplicado | marcador `<!-- terraform-plan-aula10 -->` |
| Bônus: deploy com `GITHUB_SHA` | container recebe `GITHUB_SHA`; `/version` mostra o commit e o health check confere |
| Bônus: notificação de deploy | comentário automático no commit ("🚀 Deploy em produção concluído") |
| Bônus: `terraform fmt -check` | primeiro step do plan |
| Bônus: destroy separado com aprovação manual | `terraform-destroy.yml` + environment `destroy` com *required reviewer* |
| Bônus: GitHub Environment com protection rule | `production`: deploy só a partir da `main`; `destroy`: aprovação obrigatória |

## Como reproduzir

Pré-requisitos: sessão do Learner Lab ativa, AWS CLI, Terraform ≥ 1.10, `gh` autenticado.

1. **State remoto (uma vez):** `./aula-10/terraform/bootstrap-backend.sh`. O nome do bucket
   (`technova-tfstate-aula10-a6c8f018`) é fixo e precisa ser único na AWS: para reproduzir em outra conta,
   troque-o em `bootstrap-backend.sh` e no `backend "s3"` do `provider.tf`.
2. **Secrets do repositório** (Settings → Secrets and variables → Actions):
   - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` — da sessão atual do Lab
     (atualizar a cada nova sessão);
   - `EC2_SSH_KEY` — chave privada do deploy (`ssh-keygen -t ed25519 -f ~/.ssh/technova-aula10`; a
     pública vai em `aula-10/terraform/technova-deploy.pub`).
3. **Testar a autenticação:** Actions → *AWS Check* → Run workflow.
4. **Infra:** abrir um PR alterando `aula-10/terraform/` → conferir o plan no comentário → merge → o
   *Terraform Apply* cria a EC2.
5. **Deploy:** push na `main` alterando `aula-10/technova-api/` (ou Actions → *CD Pipeline* → Run
   workflow) → conferir o health check no log e `http://<IP-da-EC2>:3000/version`.
6. **Rollback:** `./aula-10/rollback.sh sha-<commit>` (ver o runbook).

O IP da EC2 muda quando o Lab reinicia a instância; o `cd.yml` e o `rollback.sh` a encontram pela tag
`Role=technova-api-deploy`.

## Evidências

| Evidência | Link |
|-----------|------|
| Plan comentado no PR (infra criada via GitOps) | [PR #4](https://github.com/Sir-Jr/unifaat-devops-portfolio/pull/4) · [screenshots/plan-pr-comment.png](screenshots/plan-pr-comment.png) |
| Apply após o merge (6 recursos criados) | [run 40155338659](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/runs/40155338659) · [screenshots/apply-success.png](screenshots/apply-success.png) |
| Pipeline CD verde (lint → test → build-push → deploy) | [run 40155820969](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/runs/40155820969) (push) · [run 40156320739](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/runs/40156320739) (manual, mesmo commit) · [screenshots/cd-pipeline-green.png](screenshots/cd-pipeline-green.png) |
| Health check no log do workflow | [screenshots/health-check-pass.png](screenshots/health-check-pass.png) |
| Deploy automático de uma mudança de código (`/version`) | [run 40155711755](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/runs/40155711755) |
| Guard de destroy (falha sem rótulo, passa com `aprovado-destroy`) | [PR #5](https://github.com/Sir-Jr/unifaat-devops-portfolio/pull/5) |
| Rollback testado | [evidencias/rollback-teste.txt](evidencias/rollback-teste.txt) |
| Downtime do Recreate medido | [evidencias/downtime-recreate.txt](evidencias/downtime-recreate.txt) |
