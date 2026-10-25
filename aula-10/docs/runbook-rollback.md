# Runbook — Rollback de deploy da TechNova API

## Quando usar

- O deploy passou no health check, mas uma funcionalidade quebrou em produção.
- Bug crítico ou aumento de erros logo depois de um deploy.
- O pipeline de CD falhou no health check e a versão anterior precisa voltar já.

Rollback não substitui a correção: depois de estabilizar, a correção entra por um novo commit na
`main`, que gera um deploy normal pelo `cd.yml`.

## Pré-requisitos

- Sessão do Learner Lab ativa e credenciais no `~/.aws/credentials` (`aws sts get-caller-identity`).
- Chave SSH do deploy (`~/.ssh/technova-aula10`, a mesma do secret `EC2_SSH_KEY`).
- A tag de destino existe no ECR (as tags `sha-*` mais recentes são mantidas pela lifecycle policy).

## 1. Escolher a versão de destino

Cada deploy publica `sha-<commit curto>` no ECR. Para achar a última versão estável:

```bash
# Tags no ECR, da mais nova para a mais antiga
aws ecr describe-images --repository-name technova-api --region us-east-1 \
  --query 'reverse(sort_by(imageDetails,&imagePushedAt))[].[imageTags[0], imagePushedAt]' --output table

# Commits que geraram cada tag
git log --oneline -- aula-10/technova-api
```

Os comentários "🚀 Deploy em produção concluído" nos commits também mostram qual imagem foi para o ar.

## 2. Executar (script)

```bash
./aula-10/rollback.sh sha-COMMIT_BOM
```

O script faz o mesmo Recreate do pipeline:

1. confere se a tag existe no ECR;
2. acha a EC2 de produção pela tag `Role=technova-api-deploy` (o IP muda quando o Lab reinicia);
3. via SSH: **login no ECR antes do pull** → `docker stop` → `docker rm` → `docker pull` → `docker run`
   (com o commit lido do label OCI da imagem, para o `/version` continuar rastreável);
4. health check em `/health` e mostra o `/version` antes e depois.

## 3. Executar à mão (sem o script)

```bash
HOST=$(aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Role,Values=technova-api-deploy" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress | [0]' --output text)
ssh -i ~/.ssh/technova-aula10 ubuntu@$HOST

# --- na EC2 ---
REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com
aws ecr get-login-password --region us-east-1 \
  | sudo docker login --username AWS --password-stdin "$REGISTRY"      # login ANTES do pull
sudo docker stop technova-api && sudo docker rm technova-api
sudo docker pull "$REGISTRY/technova-api:sha-COMMIT_BOM"
# commit gravado na imagem pelo CI, para o /version continuar rastreável
SHA=$(sudo docker inspect -f '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$REGISTRY/technova-api:sha-COMMIT_BOM")
sudo docker run -d --name technova-api -p 3000:3000 --restart unless-stopped \
  -e NODE_ENV=production -e IMAGE_TAG=sha-COMMIT_BOM \
  -e GITHUB_SHA="$SHA" -e DEPLOY_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "$REGISTRY/technova-api:sha-COMMIT_BOM"
curl -s http://localhost:3000/health
```

A EC2 usa o `LabInstanceProfile`, então o `aws ecr get-login-password` funciona nela sem copiar
credenciais.

## 4. Verificar

- `curl http://$HOST:3000/health` responde `{"status":"ok",...}`.
- `curl http://$HOST:3000/version` mostra o commit esperado (ou 404, se a versão de destino é anterior
  à rota `/version`).
- `sudo docker ps` mostra a imagem `technova-api:sha-COMMIT_BOM` em `Up`.

## 5. Depois do rollback

- Avisar o time: versão revertida, motivo e horário.
- Atenção: o próximo push na `main` que alterar a API faz um novo deploy e substitui o rollback.
  Corrija o problema antes, ou reverta o commit com `git revert`.

## Teste executado

Em 24/10/2026: produção em `sha-11f1f32` (v1.1.0) → rollback para `sha-bbeaec3` (primeiro deploy; o
`/version` passou a responder 404) → volta para `sha-11f1f32`, com health check OK nas duas trocas.
Saída completa em [`../evidencias/rollback-teste.txt`](../evidencias/rollback-teste.txt).
