# ============================================
# Estágio 1: Dependências (builder)
# ============================================
FROM node:22-alpine AS builder

WORKDIR /app

# Copiar apenas os package files primeiro (aproveita o cache de layers)
COPY package*.json ./

# Instalar apenas as dependências de produção
RUN npm ci --omit=dev && npm cache clean --force

# ============================================
# Estágio 2: Runtime (imagem final)
# ============================================
FROM node:22-alpine AS runtime

# Metadata da imagem (OCI)
LABEL org.opencontainers.image.source="https://github.com/Sir-Jr/unifaat-devops-portfolio"
LABEL org.opencontainers.image.description="TechNova API - Sistema de gestão de pedidos"

ENV NODE_ENV=production

WORKDIR /app

# Atualizar os pacotes do Alpine (correções de segurança do openssl/zlib
# apontadas pelo scan do ECR) e criar o usuário não-root
RUN apk upgrade --no-cache && \
    addgroup -g 1001 -S nodejs && \
    adduser -S technova -u 1001 -G nodejs

# Copiar as dependências do builder e o código da aplicação
# (arquivos ficam do root: o usuário da app só lê, não altera)
COPY --from=builder /app/node_modules ./node_modules
COPY . .

# Usar usuário não-root
USER technova

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
