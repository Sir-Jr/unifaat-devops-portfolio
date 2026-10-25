#!/usr/bin/env bash
# ============================================================
# ecr-push.sh — build e push da TechNova API no Amazon ECR
# ============================================================
# Fluxo: garante o repositório -> login -> build -> tag -> push
#
# Tags publicadas:
#   sha-XXXXXXX   sempre (SHA curto do commit, rastreável)
#   latest        sempre (conveniência: último build publicado)
#   X.Y.Z, X.Y, X quando o commit tem uma git tag vX.Y.Z
#
# Uso:  ./ecr-push.sh            (a partir de qualquer pasta)
# Requer: AWS CLI com as credenciais da sessão do Learner Lab, Docker e Git.
#
# Variáveis opcionais:
#   AWS_REGION      região (padrão us-east-1)
#   ECR_REPOSITORY  nome do repositório (padrão technova-api)
#   GIT_TAG         força a versão (ex.: v1.2.3) em vez de ler do git
#   ECR_SKIP_LOGIN=1  não faz docker login (o CI já logou com amazon-ecr-login)
#   ECR_SKIP_BUILD=1  usa a imagem local technova-api:local já buildada
#   ALLOW_DIRTY=1     publica mesmo com alterações não commitadas em technova-api/
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/technova-api"

REGION="${AWS_REGION:-us-east-1}"
REPO="${ECR_REPOSITORY:-technova-api}"
LOCAL_IMAGE="technova-api:local"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
ECR_URI="$REGISTRY/$REPO"

# O ID da conta não aparece na saída (evidências e logs do CI são públicos)
mask() { sed -u "s/$ACCOUNT_ID/************/g"; }

# ---- Tags ----
# A tag sha- precisa corresponder ao código buildado: com alterações não
# commitadas na aplicação, o script para (ALLOW_DIRTY=1 ignora a checagem).
if [ "${ALLOW_DIRTY:-0}" != "1" ] && [ -n "$(git -C "$SCRIPT_DIR" status --porcelain -- technova-api)" ]; then
  echo "ERRO: há alterações não commitadas em technova-api/ — a tag sha- não corresponderia ao código." >&2
  echo "      Faça commit (ou use ALLOW_DIRTY=1 por sua conta e risco)." >&2
  exit 1
fi
SHA_TAG="sha-$(git -C "$SCRIPT_DIR" rev-parse --short=7 HEAD)"
TAGS=("$SHA_TAG" "latest")

GIT_TAG="${GIT_TAG:-$(git -C "$SCRIPT_DIR" tag --points-at HEAD --list 'v*.*.*' | sort -V | tail -n 1)}"
if [[ "$GIT_TAG" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"; MINOR="${BASH_REMATCH[2]}"; PATCH="${BASH_REMATCH[3]}"
  TAGS+=("$MAJOR.$MINOR.$PATCH" "$MAJOR.$MINOR" "$MAJOR")
  echo "==> Release detectada: $GIT_TAG"
elif [ -n "$GIT_TAG" ]; then
  echo "AVISO: tag '$GIT_TAG' não segue vX.Y.Z — publicando só sha e latest." >&2
fi

echo "==> Região: $REGION | Repositório: $REPO"
echo "==> Tags: ${TAGS[*]}"

# ---- 1. Repositório (idempotente) ----
echo "==> Garantindo o repositório ECR ($REPO)..."
if aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" >/dev/null 2>&1; then
  echo "    já existe"
else
  aws ecr create-repository --repository-name "$REPO" --region "$REGION" \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE >/dev/null
  echo "    criado"
fi

# Bônus: scan de vulnerabilidades a cada push + lifecycle policy
# (não interrompe o push se o Lab negar essas permissões)
if aws ecr put-image-scanning-configuration --repository-name "$REPO" --region "$REGION" \
     --image-scanning-configuration scanOnPush=true >/dev/null; then
  echo "    scan on push habilitado"
else
  echo "AVISO: não foi possível habilitar o scan on push" >&2
fi
if aws ecr put-lifecycle-policy --repository-name "$REPO" --region "$REGION" \
     --lifecycle-policy-text "file://$SCRIPT_DIR/ecr-lifecycle-policy.json" >/dev/null; then
  echo "    lifecycle policy aplicada"
else
  echo "AVISO: não foi possível aplicar a lifecycle policy" >&2
fi

# ---- 2. Login ----
if [ "${ECR_SKIP_LOGIN:-0}" != "1" ]; then
  echo "==> Login no ECR..."
  aws ecr get-login-password --region "$REGION" \
    | docker login --username AWS --password-stdin "$REGISTRY" 2>&1 | mask
fi

# ---- 3. Build (multi-stage) ----
if [ "${ECR_SKIP_BUILD:-0}" != "1" ]; then
  echo "==> Build..."
  # sem atestados (provenance/SBOM): o push vira uma imagem simples, que o
  # scan básico do ECR consegue analisar e a lifecycle policy não fragmenta
  docker build --provenance=false --sbom=false -t "$LOCAL_IMAGE" "$APP_DIR"
fi

# ---- 4. Tag e push ----
echo "==> Tag e push..."
for tag in "${TAGS[@]}"; do
  docker tag "$LOCAL_IMAGE" "$ECR_URI:$tag"
  echo "--- push :$tag"
  docker push --quiet "$ECR_URI:$tag" | mask
done

echo "==> Tags no ECR:"
aws ecr describe-images --repository-name "$REPO" --region "$REGION" \
  --query 'reverse(sort_by(imageDetails,&imagePushedAt))[].[join(`, `, imageTags || [`<untagged>`]), imagePushedAt]' \
  --output table

echo "==> Pronto! Imagem publicada:"
for tag in "${TAGS[@]}"; do
  echo "    $ECR_URI:$tag"
done | mask
