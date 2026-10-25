#!/usr/bin/env bash
# ============================================================
# rollback.sh — volta a produção para uma tag anterior do ECR
# ============================================================
# Mesmo Recreate do cd.yml, executado à mão (runbook: docs/runbook-rollback.md).
#   ./aula-10/rollback.sh sha-abc1234
# Requer: AWS CLI com a sessão do Lab e a chave SSH do deploy.
# ============================================================
set -euo pipefail

TAG="${1:?uso: $0 <tag do ECR, ex.: sha-abc1234>}"
REGION="${AWS_REGION:-us-east-1}"
REPO="technova-api"
CONTAINER="technova-api"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/technova-aula10}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
mask() { sed -u "s/$ACCOUNT_ID/************/g"; }

echo "==> Conferindo se a tag existe no ECR..."
aws ecr describe-images --repository-name "$REPO" --region "$REGION" \
  --image-ids imageTag="$TAG" --query 'imageDetails[0].imagePushedAt' --output text

HOST="$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Role,Values=technova-api-deploy" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress | [0]' --output text)"
[ -n "$HOST" ] && [ "$HOST" != "None" ] || { echo "ERRO: EC2 de produção não encontrada" >&2; exit 1; }
echo "==> EC2 de produção: $HOST"

show_version() {
  local code
  code=$(curl -s -o /tmp/rollback-version.json -w '%{http_code}' "http://$HOST:3000/version" || true)
  if [ "$code" = "200" ]; then cat /tmp/rollback-version.json; echo; else echo "HTTP $code (versão anterior à rota /version)"; fi
}

echo "==> Versão no ar antes do rollback:"
show_version

ssh -i "$SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "ubuntu@$HOST" \
  "REGISTRY='$REGISTRY' TAG='$TAG' CONTAINER='$CONTAINER' REGION='$REGION' bash -s" <<'REMOTE' 2>&1 | mask
set -euo pipefail
echo "--> Login no ECR (antes do pull)"
# sem login não há pull: aborta ANTES de derrubar o container atual
if ! aws ecr get-login-password --region "$REGION" \
     | sudo docker login --username AWS --password-stdin "$REGISTRY" >/tmp/ecr-login.log 2>&1; then
  cat /tmp/ecr-login.log >&2
  echo "ERRO: login no ECR falhou — produção mantida na versão atual" >&2
  exit 1
fi
echo "Login Succeeded"
echo "--> Recreate: stop + rm"
sudo docker stop "$CONTAINER" >/dev/null || true
sudo docker rm "$CONTAINER" >/dev/null || true
echo "--> Pull :$TAG"
sudo docker pull -q "$REGISTRY/technova-api:$TAG"
# commit gravado na imagem pelo CI (label OCI) — mantém o /version rastreável
SHA=$(sudo docker inspect -f '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$REGISTRY/technova-api:$TAG")
echo "--> Run :$TAG (commit ${SHA:-desconhecido})"
sudo docker run -d --name "$CONTAINER" -p 3000:3000 --restart unless-stopped \
  -e NODE_ENV=production -e IMAGE_TAG="$TAG" -e GITHUB_SHA="${SHA:-desconhecido}" \
  -e DEPLOY_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "$REGISTRY/technova-api:$TAG" >/dev/null
sudo docker ps --filter "name=$CONTAINER" --format '{{.Image}}  {{.Status}}'
REMOTE

echo "==> Health check:"
for _ in $(seq 1 20); do
  if curl -fsS "http://$HOST:3000/health" 2>/dev/null; then
    echo
    echo "==> Versão no ar depois do rollback:"
    show_version
    echo "==> OK: produção em technova-api:$TAG"
    exit 0
  fi
  sleep 3
done
echo "ERRO: health check falhou depois do rollback" >&2
exit 1
