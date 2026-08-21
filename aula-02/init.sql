-- Executado automaticamente pelo Postgres na primeira inicialização do volume
CREATE TABLE IF NOT EXISTS pedidos (
  id SERIAL PRIMARY KEY,
  cliente VARCHAR(100) NOT NULL,
  item VARCHAR(100) NOT NULL,
  quantidade INTEGER NOT NULL DEFAULT 1,
  status VARCHAR(20) NOT NULL DEFAULT 'pendente',
  criado_em TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO pedidos (cliente, item, quantidade, status) VALUES
  ('TechNova Corp', 'Licença Enterprise', 1, 'aprovado'),
  ('StartupXYZ', 'Plano Básico', 3, 'pendente'),
  ('MegaLtda', 'Consultoria DevOps', 1, 'em_andamento');
