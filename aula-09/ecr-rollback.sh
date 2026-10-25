#!/usr/bin/env bash
# ============================================================
# ecr-rollback.sh — pull de uma tag do ECR e (re)deploy local
# ============================================================
# Simula o servidor de produção: remove a imagem local, faz pull da tag
# pedida no ECR, sobe o container e confere o /health.
# Rollback = rodar de novo com uma tag anterior.
#
# Uso:  ./ecr-rollback.sh 1.0.0      (padrão: latest)
# ============================================================
set -euo pipefail

TAG="${1:-latest}"
REGION="${AWS_REGION:-us-east-1}"
REPO="${ECR_REPOSITORY:-technova-api}"
NAME="technova-prod"
PORT="${PORT:-3000}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
IMAGE="$REGISTRY/$REPO:$TAG"
mask() { sed -u "s/$ACCOUNT_ID/************/g"; }

echo "==> Login no ECR..."
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY" 2>&1 | mask

echo "==> Parando o container atual ($NAME)..."
docker rm -f "$NAME" >/dev/null 2>&1 || true

echo "==> Removendo cópia local (força o pull do registry)..."
docker rmi "$IMAGE" >/dev/null 2>&1 || true

echo "==> Pull :$TAG"
docker pull "$IMAGE" 2>&1 | mask

echo "==> Deploy do container $NAME na porta $PORT..."
docker run -d --name "$NAME" -p "$PORT:3000" "$IMAGE" >/dev/null

echo "==> Health check..."
for _ in $(seq 1 10); do
  if curl -fsS "http://localhost:$PORT/health" 2>/dev/null; then
    echo
    echo "==> OK: rodando $REPO:$TAG ($(docker inspect -f '{{.Image}}' "$NAME" | cut -c1-19))"
    exit 0
  fi
  sleep 1
done
echo "ERRO: /health não respondeu" >&2
docker logs "$NAME" >&2
exit 1
