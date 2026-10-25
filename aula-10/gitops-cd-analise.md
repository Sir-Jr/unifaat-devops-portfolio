# GitOps + CD — Análise (Aula 10)

Infraestrutura gerenciada por PR (plan no PR, apply no merge) e deploy contínuo da TechNova API numa
EC2, no AWS Academy Learner Lab (`us-east-1`).

## 1. Fluxo GitOps: plan no PR, apply no merge

A ideia do GitOps é que o Git vire a fonte da verdade da infraestrutura: o que está na `main` é o que existe na AWS, e ninguém roda `terraform apply` da própria máquina. Foi assim que a EC2 desta aula nasceu. Abri o PR #4 com os arquivos do Terraform, o workflow rodou o plan e comentou no próprio PR que ia criar 6 recursos sem destruir nada, eu fiz o merge e o apply rodou sozinho no Actions. O plan no PR faz sentido porque mostra o efeito real da mudança antes de ela acontecer, e no lugar onde a revisão já acontece: quem revisa vê o que vai mudar na AWS, e não só o diff dos arquivos `.tf`. O apply no merge fecha o ciclo, porque o merge passa a ser a aprovação humana e depois dele não sobra passo manual para alguém esquecer ou fazer diferente. Por isso aceitei o `-auto-approve`, mas com um porém: no merge o apply calcula um plan novo, e se a `main` mudou nesse meio tempo ele pode fazer algo diferente do que foi revisado no PR, inclusive um destroy, já que a trava de destroy só existe no plan. Para isso funcionar, o state precisa ficar remoto (S3 com versionamento, criptografia e lock nativo), porque o plan e o apply rodam em máquinas diferentes, e os dois workflows estão no mesmo grupo de `concurrency` para nunca brigarem pelo lock. Coloquei ainda algumas travas: o `terraform fmt -check`, o comentário que é atualizado em vez de duplicado a cada push, e um bloqueio para plan que destrói recursos, que só passa com o rótulo `aprovado-destroy` no PR. Testei isso no PR #5 mudando a descrição do security group, o que forçava recriar 4 recursos: o check falhou, passou depois que coloquei o rótulo, e fechei o PR sem merge.

## 2. Autenticação no Learner Lab e por que OIDC seria o ideal

No Lab os workflows se autenticam com as três credenciais temporárias da sessão (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_SESSION_TOKEN`) guardadas como secrets do repositório e passadas para o `aws-actions/configure-aws-credentials@v4`, com o ID da conta mascarado nos logs e no comentário do plan. A EC2 não recebe credencial nenhuma: ela usa o `LabInstanceProfile`, a role que o próprio Lab já oferece, e é com ela que o `aws ecr get-login-password` funciona no deploy. O problema desse modelo é que as credenciais expiram a cada sessão do Lab, então preciso atualizar os secrets toda vez ou os workflows falham com `ExpiredToken`, e enquanto valem são segredos parados no GitHub que dariam acesso à conta se vazassem. Em produção o caminho certo seria OIDC com uma role IAM: o GitHub gera um token por execução, a AWS confia nesse emissor e troca o token por credenciais curtas da role, com condição no repositório e na branch, sem nenhuma chave guardada. No workflow mudaria pouca coisa, basicamente trocar as três credenciais por `role-to-assume` e dar `id-token: write` nas permissões. Só que para isso é preciso criar o Identity Provider OIDC e a role, e a role `voclabs` do Lab nega essas permissões de IAM, por isso não existe `oidc.tf` nesta entrega.

## 3. Estratégia Recreate

O deploy entra na EC2 por SSH com o `appleboy/ssh-action`, faz login no ECR, para e remove o container antigo, baixa a imagem nova e sobe o container, e depois o pipeline testa o `/health` até 20 vezes e falha se não receber 200. A imagem vai para o ar pela tag `sha-` do commit e o container recebe o `GITHUB_SHA`, então o health check também confere se o `/version` mostra o commit daquele pipeline. O lado bom do Recreate é a simplicidade: um host, um container, poucos passos, nunca duas versões rodando juntas e nenhum load balancer para pagar. O lado ruim é que a aplicação fica fora do ar entre o stop e a nova versão subir, e como o pull acontece depois do stop, uma imagem nova aumenta essa janela. Se a versão nova não subir, a produção fica parada até alguém fazer o rollback. Medi isso consultando o `/health` a cada meio segundo durante um deploy com a imagem já em cache na EC2, e a API ficou fora por uns 1 a 2 segundos (2 falhas em 120 consultas, [log](evidencias/downtime-recreate.txt)). Eu usaria Recreate em desenvolvimento, homologação, aplicação interna ou janela de manutenção, ou quando duas versões não podem conviver. Para produção sem downtime o caminho é Blue-Green ou Canary, que são as próximas aulas.

## 4. Continuous Delivery × Continuous Deployment

A diferença está em quem decide a ida para produção. Na Continuous Delivery tudo é automático até a imagem estar pronta e validada, mas o deploy em produção espera alguém apertar o botão. Na Continuous Deployment todo commit que passa no pipeline vai sozinho para produção, o que exige testes, health check e rollback em que dá para confiar. O que montei aqui é Continuous Deployment: quando fiz o commit da rota `/version`, ela chegou na EC2 sem eu fazer nada, e o próprio pipeline conferiu que o commit no ar era o novo. Para virar Continuous Delivery bastaria colocar revisor obrigatório no environment `production`, e o job de deploy passaria a esperar aprovação. Esse mecanismo já está em uso no environment `destroy`, que exige minha aprovação antes do `terraform-destroy.yml` rodar.

## 5. Rollback

O procedimento está em [`docs/runbook-rollback.md`](docs/runbook-rollback.md) e automatizado no [`rollback.sh`](rollback.sh). Na prática é escolher no ECR a última tag `sha-` estável, entrar na EC2 por SSH, fazer o login no ECR antes do pull (`aws ecr get-login-password | docker login`) e repetir o Recreate com a tag antiga, conferindo o health check no final. Testei em 24/10 voltando a produção de `sha-11f1f32` para `sha-bbeaec3`, que é o primeiro deploy, quando o `/version` passou a dar 404 como esperado por ser uma versão anterior à rota, e depois voltei para `sha-11f1f32`, com o health check OK nas duas trocas ([saída](evidencias/rollback-teste.txt)).

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
| O apply gera um plan novo no merge e não tem a trava de destroy do plan | Salvar o plan revisado como artefato e aplicar exatamente ele, ou repetir a checagem de destroy no apply |
| Sem estimativa de custo no plan | Infracost no `terraform-plan.yml` (exige chave de API) |
