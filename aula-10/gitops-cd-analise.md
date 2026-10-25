# GitOps + CD — Análise (Aula 10)

Infraestrutura gerenciada por PR (plan no PR, apply no merge) e deploy contínuo da TechNova API numa
EC2, no AWS Academy Learner Lab (`us-east-1`).

## 1. Fluxo GitOps: plan no PR, apply no merge

```
branch → PR ──► terraform-plan.yml ──► comentário com o plan ──► revisão ──► merge na main
                 (fmt, init, validate, plan;                                     │
                  falha = PR não deve ser mergeado)                              ▼
                                                              terraform-apply.yml (apply -auto-approve)
```

- **O Git é a fonte da verdade.** O que está na `main` é o que existe na AWS; nenhuma pessoa roda
  `terraform apply` da própria máquina. A EC2 desta aula foi criada assim: PR #4 com o plan
  `6 to add, 0 to change, 0 to destroy` comentado, merge, e o apply rodou no Actions.
- **Plan no PR** mostra o efeito real da mudança antes de ela acontecer, no lugar onde a revisão já
  acontece. Quem revisa vê "o que vai mudar na AWS", não só o diff do `.tf`.
- **Apply no merge**: o merge é a aprovação humana; depois dele não há passo manual para esquecer ou
  fazer diferente. O `-auto-approve` é seguro porque o plan já foi revisado no PR.
- **State remoto** (S3 com versionamento, criptografia e lock nativo `use_lockfile`): plan e apply rodam
  em runners diferentes e precisam ver o mesmo state. Os dois workflows também compartilham um grupo de
  `concurrency`, então nunca disputam o lock.
- **Proteções extras implementadas:** `terraform fmt -check` no plan; o comentário é atualizado (não
  duplicado) a cada push; e um plan que **destrói** recursos falha até o PR receber o rótulo
  `aprovado-destroy`. Testado no PR #5: mudar a descrição do security group gerou `4 to destroy`, o check
  falhou, passou depois do rótulo, e o PR foi fechado sem merge.

## 2. Autenticação no Learner Lab e por que OIDC seria o ideal

**Como está:** os workflows usam `aws-actions/configure-aws-credentials@v4` com as 3 credenciais
temporárias da sessão do Lab guardadas como secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
`AWS_SESSION_TOKEN`). O ID da conta é mascarado (`::add-mask::`) em todos os logs e no comentário do plan.

Na EC2 não há credencial copiada: ela usa o `LabInstanceProfile` (role `LabRole`, que já existe no Lab).
O `aws ecr get-login-password` do deploy funciona com a role da instância.

**Problemas desse modelo:**
- As credenciais expiram a cada sessão do Lab. Os 3 secrets precisam ser atualizados toda vez, senão os
  workflows falham com `ExpiredToken`.
- São segredos de longa permanência no GitHub (enquanto a sessão vale): se vazarem, dão acesso à conta.

**Em produção: OIDC + role IAM.** O GitHub emite um token OIDC por execução; a AWS confia nesse emissor
(Identity Provider) e troca o token por credenciais de curta duração de uma role, com condição no
repositório/branch. Nenhuma chave fica guardada; no workflow só mudaria a linha
`role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/github-actions-terraform` (com `permissions: id-token: write`).

**Por que o Lab não permite:** criar o OIDC Identity Provider e a role exige permissões de IAM
(`iam:CreateOpenIDConnectProvider`, `iam:CreateRole`) que a role `voclabs` do Lab nega. Por isso não há
`oidc.tf` nesta entrega.

## 3. Estratégia Recreate

O deploy (`cd.yml`, job `deploy`, via `appleboy/ssh-action`) faz: **login no ECR → stop → rm → pull → run**,
seguido de health check com até 20 tentativas; se o `/health` não responder 200, o pipeline falha. A
imagem é publicada e implantada pela tag `sha-<commit>`, e o container recebe `GITHUB_SHA`: o health check
também confere se o `/version` no ar mostra o commit do pipeline.

| Prós | Contras |
|------|---------|
| Simples: um container, um host, poucos passos | Indisponibilidade entre o `stop` e a nova versão subir |
| Nunca há duas versões rodando juntas (sem conflito de schema, sessão ou porta) | O pull acontece depois do `stop`: imagem nova = mais tempo fora do ar |
| Barato: não precisa de load balancer nem capacidade dobrada | Se a nova versão não sobe, a produção fica fora até o rollback |

**Medição:** num deploy com a imagem já em cache na EC2, o `/health` consultado a cada 0,5 s ficou fora
por ~1–2 s (2 falhas em 112 consultas). Com uma imagem nova, o tempo de download entra nessa janela.

**Quando usar:** ambientes de desenvolvimento/homologação, janelas de manutenção, aplicações internas
que toleram segundos de indisponibilidade, ou quando duas versões não podem coexistir. Para produção sem
downtime, Blue-Green (Aula 11) ou Canary (Aula 12).

## 4. Continuous Delivery × Continuous Deployment

| | Continuous Delivery | Continuous Deployment |
|--|--|--|
| Até onde é automático | até a imagem pronta e validada | até produção |
| Ida para produção | decisão humana (botão/aprovação) | todo commit aprovado na `main` vai sozinho |
| Pré-requisito | pipeline confiável | testes e health check confiáveis + rollback rápido |

Este projeto faz **Continuous Deployment**: um push na `main` que altera a API chega à EC2 sem
intervenção (testado com a rota `/version`: commit `b75cdf0` → deploy automático → `/version` mostrando o
commit). Para virar **Continuous Delivery**, bastaria adicionar *Required reviewers* no environment
`production` (Settings → Environments): o job `deploy` passa a esperar a aprovação. Esse mecanismo está em
uso no environment `destroy`, que exige aprovação antes do `terraform-destroy.yml`.

## 5. Rollback

Procedimento completo em [`docs/runbook-rollback.md`](docs/runbook-rollback.md); automatizado em
[`rollback.sh`](rollback.sh). Resumo: escolher a tag `sha-*` estável no ECR → SSH na EC2 →
**`aws ecr get-login-password | docker login` antes do pull** → stop → rm → pull → run → health check.

Testado em 24/10: `sha-11f1f32` → `sha-bbeaec3` (o `/version` passou a dar 404, como esperado para a
versão anterior à rota) → `sha-11f1f32` ([saída](evidencias/rollback-teste.txt)).

## 6. Limitações e o que melhoraria

| Limitação | O que melhoraria |
|-----------|------------------|
| Credenciais do Lab expiram por sessão e ficam como secrets | OIDC + role IAM (fora do Lab) |
| SSH (22) aberto para `0.0.0.0/0`, porque os runners não têm IP fixo; o `ssh-action` não confere a host key | Restringir aos ranges de `api.github.com/meta`, ou trocar SSH por AWS SSM Run Command (sem porta aberta) e fixar a host key |
| Recreate tem downtime e o pull fica dentro da janela | `docker pull` antes do `stop`; depois, Blue-Green/Canary com load balancer |
| Uma única EC2, sem redundância | Auto Scaling Group / ECS |
| Health check que falha não faz rollback sozinho | Job de rollback automático para a última tag `sha-*` saudável |
| O `terraform-plan` não é check obrigatório na `main` (o filtro de paths faria PRs sem `.tf` esperarem para sempre) | Um job "guarda" que sempre roda e só executa o plan quando há `.tf` alterado |
| Aprovação obrigatória de PR não é usada (repositório de uma pessoa só) | Em equipe: *Require approvals* + CODEOWNERS para `aula-10/terraform/` |
| O IP público muda quando o Lab reinicia a EC2 (o pipeline busca pela tag, mas a URL externa muda) | Elastic IP ou load balancer com DNS |
| Sem estimativa de custo no plan | Infracost no `terraform-plan.yml` (exige chave de API) |
