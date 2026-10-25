#!/usr/bin/env bash
# ============================================================
# bootstrap-backend.sh — cria o bucket S3 do state remoto (uma vez)
# ============================================================
# O backend precisa existir antes do primeiro "terraform init", então ele
# não é gerenciado pelo próprio Terraform (problema do ovo e da galinha).
# Lock: nativo do S3 (use_lockfile = true no provider.tf), sem DynamoDB.
# Idempotente: se o bucket já existe, só reaplica as configurações.
# ============================================================
set -euo pipefail

BUCKET="${TF_STATE_BUCKET:-technova-tfstate-aula10-a6c8f018}"
REGION="us-east-1"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "==> Bucket $BUCKET já existe"
else
  echo "==> Criando bucket $BUCKET"
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
fi

echo "==> Versionamento (recupera states anteriores)"
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

echo "==> Criptografia padrão (SSE-S3)"
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "==> Bloqueio de acesso público"
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "==> Pronto: backend s3://$BUCKET (região $REGION)"
