# Portfólio DevOps — UniFAAT 2026-2

[![CI Pipeline — Aula 08](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml/badge.svg)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml)
[![CI — Aula 09 (ECR)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ci.yml/badge.svg)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ci.yml)
[![AI Code Review](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ai-review.yml/badge.svg)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/ai-review.yml)
[![CD Pipeline — Aula 10](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/cd.yml/badge.svg)](https://github.com/Sir-Jr/unifaat-devops-portfolio/actions/workflows/cd.yml)

**Aluno:** Sirlande Martins  
**RA:** 6325269  
**Disciplina:** DevOps — Centro Universitário UniFAAT  
**Professor:** Alexandre Tavares  
**Semestre:** 2026-2

## Sobre

Repositório de atividades e projetos da disciplina de DevOps.
Aqui documento minha evolução desde os fundamentos de Git e Docker até pipelines completas de CI/CD.

## Estrutura

- `aula-01/` — Fundamentos de Git e Docker
- `aula-02/` — Docker Compose (API + PostgreSQL + Redis) + IA como Copiloto DevOps
- `aula-08/` — CI Pipeline com GitHub Actions (lint → test → build), workflow em `.github/workflows/ci-aula08.yml`
- `aula-09/` — Docker Registry (Amazon ECR) + AI review de PRs com quality gate, workflows `ci.yml`, `ai-review.yml` e `security-scan.yml`
- `aula-10/` — Terraform GitOps (plan no PR, apply no merge) + pipeline de CD com deploy Recreate na EC2, workflows `terraform-plan.yml`, `terraform-apply.yml` e `cd.yml`

## Aprendizados

Cada pasta `aula-XX/` contém um `README.md` com os aprendizados, comandos praticados
e dificuldades encontradas naquela aula.
