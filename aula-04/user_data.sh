#!/bin/bash
set -e

exec > /var/log/technova-setup.log 2>&1

echo "== TechNova API setup iniciado =="

yum update -y

echo "== Instalando Node.js 18 =="
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs git

mkdir -p /opt/technova-api
cd /opt/technova-api

cat > package.json <<'EOF'
{
  "name": "technova-api",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.19.2"
  }
}
EOF

cat > server.js <<'EOF'
const express = require('express');
const os = require('os');

const app = express();
const PORT = 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'TechNova API - Rodando na AWS!',
    hostname: os.hostname(),
    timestamp: new Date().toISOString(),
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'technova-api' });
});

app.get('/orders', (req, res) => {
  res.json({
    orders: [
      { id: 1, product: 'Widget A', status: 'shipped' },
      { id: 2, product: 'Widget B', status: 'processing' },
    ],
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`TechNova API rodando na porta ${PORT}`);
});
EOF

echo "== Instalando dependências =="
npm install --omit=dev

echo "== Iniciando a API =="
nohup node server.js > /var/log/technova-api.log 2>&1 &

echo "== TechNova API setup concluído =="
