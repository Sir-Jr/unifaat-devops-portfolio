# IA no CI/CD — Análise da estratégia (Aula 09)

Documento do TF da Aula 09: registry (Amazon ECR), estratégia de tagging, AI review de Pull Requests
e quality gate da TechNova API.

## 1. Registry: por que o Amazon ECR

| | Amazon ECR | ghcr.io | Docker Hub |
|--|--|--|--|
| Onde fica | na mesma conta AWS do Learner Lab | GitHub | Docker Inc. |
| Acesso | privado por padrão, controlado pelo IAM da conta | ligado às permissões do repositório GitHub | público no plano gratuito (privado é limitado) |
| Pull em EC2/ECS | direto, com o `LabInstanceProfile` ou as credenciais da sessão | exige token do GitHub no servidor | sujeito a rate limit de pull anônimo |
| Recursos extras | scan de vulnerabilidades no push, lifecycle policy | — | scan pago |

A infraestrutura da TechNova (EC2, RDS, VPC das aulas de Terraform) já está na AWS. Com a imagem no
ECR da mesma conta, o deploy do Módulo 4 faz o pull sem sair do ambiente e sem guardar outro segredo
no servidor.

### Restrições do AWS Academy Learner Lab

- **Credenciais temporárias:** `aws_access_key_id`, `aws_secret_access_key` e `aws_session_token`
  mudam a cada sessão do Lab. O `ecr-push.sh` local é o fluxo confiável. No `ci.yml`, o push só
  funciona enquanto os 3 secrets do repositório estiverem com os valores da sessão atual.
- **Sem IAM:** o Lab não deixa criar usuários, grupos nem roles. Por isso não dá para usar um usuário
  dedicado de CI nem OIDC (role assumida pelo GitHub), que seria o padrão em produção.
- **Sem Bedrock:** o serviço exige habilitar modelos e criar roles, ambos bloqueados no Lab. O AI review
  é a Opção A do laboratório: análise por regras, sem chamada a modelo.
- **Região fixa:** tudo em `us-east-1`.
- **ECR liberado:** criar repositório, push, pull, scan on push e lifecycle policy funcionam com a
  role da sessão.

## 2. Estratégia de tagging

| Evento | Tags publicadas | Para quê |
|--------|-----------------|----------|
| `ecr-push.sh` / push na `main` | `sha-XXXXXXX` + `latest` | `sha-` identifica o commit exato; `latest` aponta para o último build |
| commit com git tag `v1.2.3` | `sha-XXXXXXX` + `latest` + `1.2.3` + `1.2` + `1` | release com versão semântica |
| Pull Request | nenhuma (só build + smoke test no CI) | imagem de código não revisado não vai para o registry |

- **`sha-XXXXXXX` (imutável na prática):** cada build tem a sua; responde "qual commit está em
  produção?" e é a tag usada no rollback.
- **`latest`:** conveniência para desenvolvimento. Ela se move a cada push, então não serve para
  deploy de produção.
- **Semver:** `1.2.3` é a release exata; `1.2` e `1` acompanham o último patch/minor, para quem aceita
  atualizações compatíveis.
- O script lê a versão de `git tag --points-at HEAD` (formato `vX.Y.Z`); no CI ela vem de
  `github.ref_name` quando o evento é uma tag. Tags fora do padrão são ignoradas com aviso.
- O repositório usa tags mutáveis (`MUTABLE`), porque `latest`, `1.2` e `1` precisam ser reapontadas.

### Ciclo de vida das imagens (`ecr-lifecycle-policy.json`)

1. Imagens sem tag (`untagged`) expiram depois de 1 dia.
2. Só os 15 builds `sha-*` mais recentes são mantidos.

Cuidado da regra 2: uma imagem de release também tem uma tag `sha-`; se ela ficar mais antiga que os
15 últimos builds, a regra a expira junto com as tags semver. Em produção, a solução seria uma regra
de maior prioridade para preservar as tags de release.

## 3. O que o AI review verifica

Script: `.github/scripts/ai-review.js` — 18 padrões, aplicados só às **linhas adicionadas** do diff.

| Severidade | Padrão | Arquivos |
|:--|:--|:--|
| 🔴 CRITICAL | secret/credencial hardcoded (`password`, `secret`, `apiKey`, `token`… = `'valor'`) | todos |
| 🔴 CRITICAL | chave de acesso AWS (`AKIA…`/`ASIA…`) | todos |
| 🔴 CRITICAL | chave privada (`BEGIN … PRIVATE KEY`) | todos |
| 🔴 CRITICAL | `eval()` | JS/TS |
| 🔴 CRITICAL | `new Function()` | JS/TS |
| 🔴 CRITICAL | command injection (`exec`/`spawn` com string montada) | JS/TS |
| 🔴 CRITICAL | SQL injection (SQL concatenado ou com `${}`) | JS/TS |
| 🔴 CRITICAL | TLS desativado (`rejectUnauthorized: false`) | todos |
| 🟡 WARNING | `console.log/debug/info` | JS/TS |
| 🟡 WARNING | `catch` vazio | JS/TS |
| 🟡 WARNING | `debugger` | JS/TS |
| 🟡 WARNING | binding em `0.0.0.0` | todos |
| 🟡 WARNING | CORS liberado para `*` | todos |
| 🟡 WARNING | `FROM …:latest` | Dockerfile |
| 🟡 WARNING | `USER root` | Dockerfile |
| 🔵 INFO | `TODO`/`FIXME`/`HACK`/`XXX` | todos |
| 🔵 INFO | `var` | JS/TS |
| 🔵 INFO | URL `http://` (exceto localhost) | todos |

O workflow dedicado `security-scan.yml` é informativo (não reprova o PR) e repete a busca de secrets (AWS key, password, chave privada,
JWT secret, `aws_secret_access_key`), confere o Dockerfile (usuário não-root, tag fixa, HEALTHCHECK,
multi-stage) e roda `npm audit --omit=dev` nas dependências de produção.

## 4. Lógica da análise

1. O workflow (`ai-review.yml`) faz checkout com `fetch-depth: 0` e gera
   `git diff origin/<base>...HEAD` em arquivo.
2. O script percorre o diff: lê o arquivo de cada bloco (`+++ b/…`) e o número da linha no arquivo
   novo pelo cabeçalho `@@ … +N,M @@`. Só as linhas que começam com `+` são testadas.
3. Arquivos ignorados: Markdown, `package-lock.json` e os próprios arquivos de regras
   (`ai-review.js` e `security-scan.yml`), que contêm os padrões e se acusariam.
4. Cada linha passa pelas regras; algumas valem só para certos arquivos (ex.: `eval` só em JS) e a de
   secrets descarta valores seguros (`${{ secrets.X }}`, `process.env`, `CHANGE_ME`, `required`…).
5. O relatório é uma tabela Markdown ordenada por severidade, com arquivo, linha, problema e trecho
   do código. O comentário no PR leva um marcador HTML oculto; nos pushes seguintes o workflow
   **atualiza** o mesmo comentário em vez de criar outro.

### Onde entraria o modelo de IA

Num ambiente com Bedrock, a etapa 4 enviaria o diff a um modelo com um prompt como o do laboratório
(Opção B): pedir os achados classificados em CRITICAL/WARNING/INFO, com arquivo, linha, descrição e
sugestão, em tabela Markdown. As regras continuariam úteis como primeira camada: são determinísticas,
não custam nada e não mandam o código para fora.

## 5. Quality gate

| Resultado | Check `ai-review` | Merge |
|-----------|:----------------:|:-----:|
| algum 🔴 CRITICAL | ❌ falha (`exit 1` no step *Quality gate*) | bloqueado |
| só 🟡 WARNING / 🔵 INFO | ✅ passa | liberado (achados ficam no comentário) |
| nenhum achado | ✅ passa | liberado |
| erro na própria análise | ❌ falha (o script sai com código 2) | bloqueado |

- O gate é um step separado, depois do comentário: mesmo reprovado, o PR recebe a explicação.
- A branch `main` tem proteção com o check `ai-review` obrigatório; sem isso o ❌ seria só visual.
- Se a análise quebra, o check falha (fail closed): um review que não rodou não aprova o PR.

## 6. Quando confiar na IA e quando exigir review humano

### Onde o veredito automático basta

- **Padrões com formato inconfundível:** chave AWS (`AKIA…`/`ASIA…`), chave privada, `eval()` e
  `new Function()` em código novo. No PR de teste (#2) os 4 CRITICAL eram problemas reais, e na
  varredura do portfólio inteiro essas regras não acusaram nada indevido. Aqui o bloqueio automático é
  seguro: o custo de um falso positivo é baixo e o de deixar passar um segredo é alto.
- **Achados de estilo (WARNING/INFO):** `console.log`, `var`, `TODO`. Eles não bloqueiam, só
  informam; dá para aceitar ou ignorar sem discussão.

A regra de **secret hardcoded** é a exceção dentro do CRITICAL: ela depende do nome da variável e
gerou os 2 falsos positivos medidos (`CHANGE_ME` e `http_tokens = "required"`). Quando ela bloqueia,
alguém precisa olhar antes de aceitar ou contestar.

### O que sempre precisa de uma pessoa, mesmo com review verde

- **Mudanças no próprio pipeline** (`.github/workflows/`, `.github/scripts/`): o `ai-review.js`
  ignora os seus arquivos de regras para não se acusar, então uma alteração que enfraquece o gate passa
  sem nenhum achado.
- **Dependências e imagem base:** o PR #3 mudou só o `package-lock.json` e recebeu ✅ porque o lock é
  ignorado; quem achou a vulnerabilidade do `body-parser` foi o `npm audit` do security scan. Da mesma
  forma, as 26 vulnerabilidades do `openssl`/`zlib` estavam na imagem base, fora do diff, e só
  apareceram no scan do ECR.
- **Credenciais e permissões de CI:** passos que usam os secrets do Lab ou mudam `permissions:` não têm
  padrão textual "errado", mas definem o que o workflow pode fazer na conta AWS e no repositório.
- **Lógica de negócio:** regras de pedido, validações e respostas da API. A análise é linha a linha e
  não sabe se o comportamento está certo.

### Override quando o gate bloquear por falso positivo

1. O autor responde no próprio PR explicando por que o achado é falso (ex.: valor de configuração,
   não segredo).
2. A correção vai para a regra, num PR separado e revisado — como foi feito com `CHANGE_ME` e
   `required` na lista de valores seguros —, e não com o desligamento do gate.
3. Em urgência, o administrador pode usar o *bypass* da proteção da `main` (a opção "Merge without
   waiting for requirements" aparece no print do gate), registrando a justificativa no PR.
4. Cada exceção na lista de valores seguros abre uma brecha (um segredo real com aquele valor também
   passaria), então ela deve ser curta e revista de tempos em tempos.

## 7. Limitações observadas

- **Falsos positivos medidos:** o script foi rodado sobre todo o código já existente no portfólio
  (~23 mil linhas de diff, aulas 01–09). A primeira versão gerou 2 CRITICAL, ambos falsos:
  `db_password = "CHANGE_ME"` num `.tfvars.example` e `http_tokens = "required"` num log de
  `terraform destroy`. Os dois valores entraram na lista de valores seguros. Os 8 WARNING restantes são
  `console.log` de inicialização do servidor e um `0.0.0.0` intencional em container: corretos como
  padrão, mas sem problema real no contexto.
- **Falsos negativos:** regex só vê o que tem o formato esperado. Um secret numa variável com nome
  neutro (`const x = 'sk-…'`), SQL montado em várias linhas ou `eval` chamado indiretamente passam.
  O mesmo vale para um `catch` vazio escrito em mais de uma linha (`} catch (e) {` e `}` na linha
  seguinte): como cada linha é analisada sozinha, ele não é detectado.
- **Contexto limitado:** a análise é linha a linha, só do que foi adicionado. Ela não sabe se o valor
  vem de input do usuário, se a função é chamada em produção ou se o código removido quebrava algo.
- **A lista de "valores seguros" corta dos dois lados:** `CHANGE_ME` deixou de ser acusado, mas um
  secret real com esse valor também passaria.
- **Escopo da Opção A:** sem modelo de linguagem, não há explicação de intenção, sugestão de correção
  nem análise de lógica de negócio — é a principal diferença para um review com Bedrock.
