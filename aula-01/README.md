# Aula 01 — Fundamentos de Git e Docker

## O que aprendi

### Git

**O modelo distribuído.** No Git, cada desenvolvedor não tem um atalho para o projeto — tem o
projeto inteiro, com todo o histórico, na própria máquina. A consequência prática é que
commitar, criar branches e navegar pelo histórico são operações locais: funcionam sem
internet e são instantâneas. Isso também significa que cada clone é, por si só, um backup
completo do repositório.

**De onde veio.** O Git foi criado por Linus Torvalds em 2005 — o mesmo criador do Linux — e
hoje é o padrão absoluto da indústria de software.

**O fluxo de trabalho e os três estados.** Entender onde um arquivo está em cada momento foi
o que fez o Git deixar de parecer arbitrário:

| Estado | O que é |
|---|---|
| **Working Directory** | onde eu edito os arquivos no dia a dia |
| **Staging Area (Index)** | área de preparação — eu escolho quais mudanças entram no próximo commit |
| **Repository (`.git/`)** | histórico permanente, feito de snapshots do projeto |

O ciclo é sempre o mesmo: editar → `git add` → `git commit` → repetir.

**Branches.** Permitem desenvolver uma funcionalidade isoladamente, sem afetar o código
principal. A imagem que funcionou para mim é a de linhas do tempo paralelas: eu experimento
na minha linha, e a `main` permanece estável até eu decidir integrar o trabalho.

### Docker

Aprendi que containerizar não é "só empacotar" — é atender a quatro requisitos que, juntos,
eliminam o problema do "funciona na minha máquina":

1. **Isolamento** — a aplicação roda em um ambiente separado do sistema host.
2. **Reprodutibilidade** — o ambiente é exatamente o mesmo em qualquer máquina.
3. **Portabilidade** — funciona no laptop do dev, no servidor de CI e em produção.
4. **Versionamento** — a definição do ambiente é um arquivo, e por isso pode ser versionada
   no Git junto com o código.

O quarto item é o que conecta as duas ferramentas da aula: o `Dockerfile` entra no mesmo
repositório que o código-fonte, então o ambiente passa a ter histórico, revisão e rollback,
exatamente como qualquer outro arquivo do projeto.

## Comandos Git praticados

```bash
git config --global init.defaultBranch main
git init
git status
git add <arquivo>
git commit -m "tipo: mensagem"
git log --oneline --graph --all
git branch / git branch -d <branch>
git checkout -b <branch>
git merge <branch>
git remote add origin <url>
git push -u origin main
git clone <url>
git pull origin main
```

## Comandos Docker praticados

```bash
docker pull node:20-alpine
docker images
docker build -t <nome>:<tag> .
docker run -d --name <nome> -p 3000:3000 <imagem>
docker run -d --rm -e NODE_ENV=production <imagem>
docker ps / docker ps -a
docker logs <container>
docker exec <container> sh -c "<comando>"
docker stop / docker start / docker rm
docker stats <container> --no-stream
```

## Como executar este container

```bash
cd aula-01/app
docker build -t portfolio-aula01:1.0 .
docker run -d -p 3000:3000 portfolio-aula01:1.0
curl http://localhost:3000
curl http://localhost:3000/health
```
