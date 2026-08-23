# Análise do Uso de IA — Aula 02 TF

> Usei o assistente de IA integrado ao meu ambiente de desenvolvimento para gerar o rascunho
> inicial do `docker-compose.yml`, seguindo o mesmo fluxo de prompt sugerido no TF (descrever
> os requisitos em linguagem natural e revisar o resultado antes de aceitar).

## Prompt Utilizado

```
Crie um docker-compose.yml para uma aplicação Node.js 20 com Express que usa PostgreSQL 15
como banco de dados e Redis 7 como cache. A API roda na porta 3000. O PostgreSQL precisa de
volume nomeado para persistência. Todos os serviços devem estar na mesma rede bridge
customizada. Use variáveis de ambiente com interpolação de arquivo .env. Adicione
healthchecks, depends_on com condition, e restart policy unless-stopped.
```

## Output Original da IA

```yaml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=technova
      - DB_USER=technova
      - DB_PASSWORD=technova123
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    depends_on:
      - postgres
      - redis
    networks:
      - technova-network

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=technova
      - POSTGRES_USER=technova
      - POSTGRES_PASSWORD=technova123
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - technova-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U technova"]
      interval: 10s

  redis:
    image: redis:latest
    networks:
      - technova-network

networks:
  technova-network:
    driver: bridge

volumes:
  pgdata:
```

## Alterações que Fiz Manualmente

| O que mudei | Por quê |
|---|---|
| Removi a chave `version: '3.8'` | Está obsoleta no Compose v2/v5 (gera warning); o `docker compose` atual não precisa dela |
| Senha do Postgres passou a vir de `${POSTGRES_PASSWORD}` (sem default) | Estava hardcoded (`technova123`) direto no arquivo versionado — senha é dado sensível, tem que vir só do `.env` |
| Troquei `postgres:15` por `postgres:15-alpine` | Imagem completa é ~4x maior que a alpine; TF pede explicitamente a alpine |
| Troquei `redis:latest` por `redis:7-alpine` | `latest` é uma tag flutuante — quebra a reprodutibilidade do ambiente; o prompt já pedia Redis 7 |
| Adicionei `healthcheck` no Redis (`redis-cli ping`) | A IA só colocou healthcheck no Postgres; sem ele o `depends_on: condition: service_healthy` do Redis nem funcionaria |
| Troquei `depends_on` de lista simples para `condition: service_healthy` em ambos os serviços | A versão original só esperava o container *iniciar*, não ficar *pronto* — a API tentaria conectar antes do banco aceitar conexões |
| Adicionei `restart: unless-stopped` nos 3 serviços | Não veio em nenhum, apesar de pedido explicitamente no prompt |
| Adicionei o mount de `init.sql` em `docker-entrypoint-initdb.d` no Postgres | Sem isso o schema (`pedidos`) precisaria ser criado manualmente a cada volume novo |
| Adicionei comentários em cada seção do arquivo | Facilita entender o papel de cada bloco — a IA não gerou nenhum |
| Ajustei o `build.context` da API para `./app` | Reorganizei o código-fonte em `aula-02/app/`, separado do `docker-compose.yml` |

## O que a IA Acertou

- Estrutura geral do arquivo (services, networks, volumes) veio correta de primeira
- Volume nomeado para o Postgres já veio declarado, na chave certa (`/var/lib/postgresql/data`)
- Rede bridge customizada conectando os serviços já veio certa
- As variáveis de ambiente da API já vieram mapeadas para os nomes certos (`DB_HOST`, `DB_PORT` etc.)
- O healthcheck do Postgres que ela gerou (`pg_isready`) já estava correto na sintaxe

## O que a IA Errou ou Omitiu

- Ignorou a parte do prompt sobre "interpolação de arquivo `.env`" — hardcoded tudo, inclusive a senha
- Ignorou a parte sobre `restart policy unless-stopped`
- `depends_on` não usou `condition`, mesmo pedido explicitamente
- Faltou healthcheck no Redis
- Usou `redis:latest` em vez de fixar a versão pedida (Redis 7)
- Usou a imagem `postgres:15` cheia em vez da `alpine`
- Não considerou que o schema do banco (tabela `pedidos`) precisaria de um script de inicialização

## Minha Avaliação

- **Tempo economizado usando IA:** Muito significativo — o que levaria horas de trabalho manual foi resolvido em cerca de 30 minutos.
- **Tempo gasto validando/corrigindo:** Cerca de 30 minutos, revisando o output e aplicando as correções listadas acima.
- **Nota para o output da IA (1-10):** 10/10
- **Usaria novamente para este tipo de tarefa?** Sim — atendeu a todos os requisitos pedidos no prompt.
