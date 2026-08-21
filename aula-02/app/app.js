const express = require('express');
const { Pool } = require('pg');
const { createClient } = require('redis');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;
const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_PORT = process.env.DB_PORT || 5432;
const DB_NAME = process.env.DB_NAME || 'technova';
const DB_USER = process.env.DB_USER || 'technova';
const DB_PASSWORD = process.env.DB_PASSWORD || 'technova';
const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const REDIS_PORT = process.env.REDIS_PORT || 6379;

const pool = new Pool({
  host: DB_HOST,
  port: DB_PORT,
  database: DB_NAME,
  user: DB_USER,
  password: DB_PASSWORD,
});

const redisClient = createClient({ url: `redis://${REDIS_HOST}:${REDIS_PORT}` });
redisClient.on('error', (err) => console.error('Erro no cliente Redis:', err.message));
redisClient.connect().catch((err) => console.error('Falha ao conectar no Redis:', err.message));

app.get('/', (req, res) => {
  res.json({
    servico: 'TechNova API - Aula 02 TF',
    aluno: 'Sirlande Martins',
    ra: '6325269',
    status: 'online',
    banco: `${DB_HOST}:${DB_PORT}/${DB_NAME}`,
    cache: `${REDIS_HOST}:${REDIS_PORT}`,
    timestamp: new Date().toISOString(),
  });
});

app.get('/health', async (req, res) => {
  const servicos = { api: 'online', banco: 'desconhecido', cache: 'desconhecido' };

  try {
    await pool.query('SELECT 1');
    servicos.banco = 'online';
  } catch (err) {
    servicos.banco = `erro: ${err.message}`;
  }

  try {
    await redisClient.ping();
    servicos.cache = 'online';
  } catch (err) {
    servicos.cache = `erro: ${err.message}`;
  }

  const status = servicos.banco === 'online' && servicos.cache === 'online' ? 'healthy' : 'degraded';
  res.status(status === 'healthy' ? 200 : 503).json({ status, uptime: process.uptime(), servicos });
});

app.get('/pedidos', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM pedidos ORDER BY id');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

app.get('/cache-test', async (req, res) => {
  try {
    const visitas = await redisClient.incr('visitas');
    res.json({ chave: 'visitas', valor: visitas });
  } catch (err) {
    res.status(500).json({ erro: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`TechNova API rodando na porta ${PORT}`);
  console.log(`Banco: ${DB_HOST}:${DB_PORT}/${DB_NAME}`);
  console.log(`Cache: ${REDIS_HOST}:${REDIS_PORT}`);
});
