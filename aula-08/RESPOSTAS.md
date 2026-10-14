# Respostas — Questões de Múltipla Escolha (Aula 08)

## Questão 1 — O que dispara a execução de um workflow do GitHub Actions?

**Resposta: b)** Eventos configurados no campo `on:` do YAML, como push, pull_request ou workflow_dispatch.

O workflow não roda sozinho em intervalo fixo (isso só aconteceria com um evento `schedule` declarado
no `on:`), nem depende de clique manual ou de administrador. No `ci-aula08.yml` deste portfólio, o
`on:` declara `push` na `main`, `pull_request` para a `main` e `workflow_dispatch` (execução manual
opcional).

## Questão 2 — Qual é a função da keyword `needs` em um workflow multi-stage?

**Resposta: c)** Cria dependência entre jobs — o job só executa se os jobs listados em `needs` passarem.

Sem `needs`, os jobs rodam em paralelo. No pipeline desta aula, `test` tem `needs: lint` e `build` tem
`needs: [lint, test]`: se o ESLint falhar, os testes e o build nem começam. Secrets, runners e
repetições são definidos por outras chaves (`secrets.*`, `runs-on`, `strategy`).

## Questão 3 — Onde devem ser armazenadas credenciais AWS para uso em GitHub Actions?

**Resposta: c)** Em GitHub Secrets (Settings → Secrets), referenciadas com `${{ secrets.NAME }}`.

Um `.env` commitado ou valores escritos no YAML ficam no histórico do Git para quem tiver acesso ao
repositório — o mascaramento do GitHub vale só para os logs e só para valores cadastrados como secret.
`runs-on` escolhe o runner e não guarda variáveis, e não existe campo `credentials:` para isso. Neste
portfólio, `AWS_REGION` está cadastrado como secret e é lido no job `build` com `${{ secrets.AWS_REGION }}`.

## Questão 4 — Qual é o propósito de environments com approval gates?

**Resposta: b)** Garantir que deploys para ambientes sensíveis (como produção) requeiram aprovação
humana antes de executar.

Um job que declara `environment: production` fica pausado até um dos *required reviewers* aprovar, e
só então recebe os secrets daquele environment. Não acelera o pipeline, não expõe secrets nos logs e
não replica o repositório.
