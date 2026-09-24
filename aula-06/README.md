# Biblioteca de Módulos Terraform — TechNova (Aula 06)

## Visão geral

Biblioteca de módulos Terraform reutilizáveis para provisionar um ambiente completo da TechNova na
AWS: rede (VPC com subnets públicas e privadas), Security Groups, servidor de aplicação (EC2) e
banco de dados (RDS PostgreSQL).

Os módulos ficam em `modules/` e não sabem nada sobre ambientes: tudo o que muda entre dev e
staging (CIDRs, nomes, nome do banco) entra como variável. Cada pasta em `environments/` é um root
module independente, com state próprio, que monta o ambiente chamando os mesmos quatro módulos.

```
aula-06/
├── README.md
├── environments/
│   ├── dev/        # 10.0.0.0/16 — technova-dev-*
│   └── staging/    # 10.1.0.0/16 — technova-staging-*
└── modules/
    ├── vpc/
    ├── security-group/
    ├── ec2/
    └── rds/
```

## Arquitetura

### Dependências entre módulos

```
                    ┌──────────────────────┐
                    │     module "vpc"     │
                    └──────────────────────┘
                     │ vpc_id  │ public_subnet_ids   │ private_subnet_ids
          ┌──────────┴───┐     │                     │
          ▼              ▼     │                     │
 ┌─────────────────┐ ┌─────────────────┐             │
 │ module "api_sg" │ │ module "rds_sg" │             │
 │ (security-group)│ │ (security-group)│             │
 └─────────────────┘ └─────────────────┘             │
   │ sg_id    │ sg_id  ▲       │ sg_id               │
   │          └────────┘       │                     │
   │   (origem da regra 5432)  │                     │
   ▼                           ▼                     ▼
 ┌──────────────────────┐    ┌──────────────────────────┐
 │ module "api_server"  │    │    module "database"     │
 │ (ec2)                │    │    (rds)                 │
 │ subnet_id =          │    │ subnet_ids =             │
 │  public_subnet_ids[0]│    │  private_subnet_ids      │
 └──────────────────────┘    └──────────────────────────┘
```

| De (output) | Para (input) |
|-------------|--------------|
| `module.vpc.vpc_id` | `module.api_sg.vpc_id`, `module.rds_sg.vpc_id` |
| `module.vpc.public_subnet_ids[0]` | `module.api_server.subnet_id` |
| `module.vpc.private_subnet_ids` | `module.database.subnet_ids` |
| `module.api_sg.sg_id` | `module.api_server.security_group_ids` e origem da regra 5432 do `rds_sg` |
| `module.rds_sg.sg_id` | `module.database.security_group_ids` |

### Infraestrutura de cada ambiente

```
VPC 10.X.0.0/16  (X = 0 no dev, 1 no staging)
│
├── Internet Gateway ── Route Table pública (0.0.0.0/0 → IGW)
│
├── us-east-1a                          ├── us-east-1b
│   ├── public-1  10.X.1.0/24           │   ├── public-2  10.X.2.0/24
│   │   └── EC2 t2.micro (api)          │   │
│   │       SG api: 80, 22              │   │
│   └── private-1 10.X.3.0/24 ─┐        │   └── private-2 10.X.4.0/24 ─┐
│                              └──── DB Subnet Group ──────────────────┘
│                                       │
│                                 RDS PostgreSQL 15 (db.t3.micro)
│                                 SG rds: 5432 apenas a partir do SG api
```

## Módulos disponíveis

| Módulo | Descrição | Inputs obrigatórios | Outputs |
|--------|-----------|---------------------|---------|
| `vpc` | VPC, subnets dinâmicas (`for_each`), IGW e route table pública | `vpc_cidr`, `project_name`, `environment`, `subnets` | `vpc_id`, `vpc_cidr`, `subnet_ids`, `public_subnet_ids`, `private_subnet_ids` |
| `security-group` | SG genérico com regras de entrada como lista de objetos e egress liberado por padrão | `name`, `vpc_id`, `environment`, `project_name` | `sg_id`, `sg_name` |
| `ec2` | Instância EC2 com AMI, subnet, SGs e user_data configuráveis | `instance_name`, `ami_id`, `subnet_id`, `security_group_ids`, `key_name`, `environment`, `project_name` | `instance_id`, `public_ip`, `private_ip` |
| `rds` | DB Subnet Group e instância RDS PostgreSQL | `db_name`, `db_username`, `db_password`, `subnet_ids`, `security_group_ids`, `environment`, `project_name` | `db_endpoint`, `db_address`, `db_name`, `db_port` |

Todos os recursos recebem as tags `Name`, `Environment`, `Project` e `ManagedBy = "terraform"`, e os
nomes seguem o padrão `<project_name>-<environment>-<recurso>`.

### Módulo VPC

**Descrição:** Cria a VPC com DNS habilitado, uma subnet para cada entrada do mapa `subnets`
(`for_each`), o Internet Gateway e uma route table pública associada só às subnets com
`type = "public"`. Subnets públicas recebem IP público automaticamente.

Como as subnets são indexadas pela chave do mapa (`aws_subnet.this["public-1"]`), remover uma
entrada destrói só aquela subnet, sem reindexar as demais (o que aconteceria com `count`).

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| vpc_cidr | string | Sim | CIDR block da VPC |
| subnets | map(object({cidr, az, type})) | Sim | Mapa de subnets; `type` deve ser `public` ou `private` (validado) |
| project_name | string | Sim | Nome do projeto |
| environment | string | Sim | Ambiente |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| vpc_id | ID da VPC criada |
| vpc_cidr | CIDR da VPC |
| subnet_ids | Mapa chave → ID de todas as subnets |
| public_subnet_ids | Lista de IDs das subnets públicas |
| private_subnet_ids | Lista de IDs das subnets privadas |

**Exemplo de uso:**
```hcl
module "vpc" {
  source       = "../../modules/vpc"
  vpc_cidr     = "10.0.0.0/16"
  project_name = "technova"
  environment  = "dev"
  subnets = {
    "public-1"  = { cidr = "10.0.1.0/24", az = "us-east-1a", type = "public" }
    "private-1" = { cidr = "10.0.3.0/24", az = "us-east-1a", type = "private" }
    "private-2" = { cidr = "10.0.4.0/24", az = "us-east-1b", type = "private" }
  }
}
```

### Módulo Security Group

**Descrição:** SG genérico, usado tanto para a API quanto para o RDS. Cada item de
`ingress_rules` vira um `aws_security_group_rule`. A origem de cada regra é **um** entre
`cidr_blocks` (faixa de IPs) e `source_security_group_id` (outro SG). Uma validação garante que
exatamente um dos dois foi informado. Sem `egress_rules`, todo tráfego de saída é liberado.

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| name | string | Sim | Nome do Security Group |
| vpc_id | string | Sim | ID da VPC |
| environment | string | Sim | Ambiente |
| project_name | string | Sim | Nome do projeto |
| description | string | Não | Descrição do SG (padrão: `Managed by Terraform`) |
| ingress_rules | list(object({from_port, to_port, protocol, description, cidr_blocks?, source_security_group_id?})) | Não | Regras de entrada (padrão: nenhuma) |
| egress_rules | list(object({from_port, to_port, protocol, cidr_blocks, description})) | Não | Regras de saída (padrão: all traffic para `0.0.0.0/0`) |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| sg_id | ID do Security Group |
| sg_name | Nome do Security Group |

**Exemplo de uso:**
```hcl
module "rds_sg" {
  source       = "../../modules/security-group"
  name         = "technova-dev-rds-sg"
  vpc_id       = module.vpc.vpc_id
  environment  = "dev"
  project_name = "technova"

  ingress_rules = [
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      source_security_group_id = module.api_sg.sg_id
      description              = "PostgreSQL from API SG"
    }
  ]
}
```

### Módulo EC2

**Descrição:** Cria uma instância EC2. AMI, tipo, subnet, SGs e key pair são configuráveis, e o
`user_data` é opcional.

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| instance_name | string | Sim | Nome da instância (tag Name) |
| ami_id | string | Sim | AMI ID |
| subnet_id | string | Sim | Subnet ID |
| security_group_ids | list(string) | Sim | Lista de SG IDs |
| key_name | string | Sim | Nome do key pair |
| environment | string | Sim | Ambiente |
| project_name | string | Sim | Nome do projeto |
| instance_type | string | Não | Tipo da instância (padrão: `t2.micro`) |
| user_data | string | Não | Script de inicialização (padrão: nenhum) |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| instance_id | ID da instância |
| public_ip | IP público |
| private_ip | IP privado |

**Exemplo de uso:**
```hcl
module "api_server" {
  source             = "../../modules/ec2"
  instance_name      = "technova-dev-api"
  ami_id             = data.aws_ami.amazon_linux.id
  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.api_sg.sg_id]
  key_name           = "vockey"
  environment        = "dev"
  project_name       = "technova"
}
```

### Módulo RDS

**Descrição:** Cria um DB Subnet Group com as subnets informadas (privadas, em pelo menos 2 AZs)
e uma instância RDS PostgreSQL privada (`publicly_accessible = false`) com storage criptografado.
Os padrões são voltados a desenvolvimento: `skip_final_snapshot = true`, sem proteção contra
exclusão, sem backups automáticos, single-AZ e alterações aplicadas imediatamente.

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| db_name | string | Sim | Nome do database |
| db_username | string | Sim | Usuário master |
| db_password | string (sensitive) | Sim | Senha master (alfanumérica) |
| subnet_ids | list(string) | Sim | Subnet IDs para o DB Subnet Group |
| security_group_ids | list(string) | Sim | SG IDs para o RDS |
| environment | string | Sim | Ambiente |
| project_name | string | Sim | Nome do projeto |
| instance_class | string | Não | Classe da instância (padrão: `db.t3.micro`) |
| engine_version | string | Não | Versão do PostgreSQL (padrão: `15`) |
| allocated_storage | number | Não | Armazenamento em GB (padrão: `20`) |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| db_endpoint | Endpoint de conexão (`host:porta`) |
| db_address | Hostname do banco |
| db_name | Nome do database |
| db_port | Porta (5432) |

**Exemplo de uso:**
```hcl
module "database" {
  source             = "../../modules/rds"
  db_name            = "technova_dev"
  db_username        = "technova_admin"
  db_password        = var.db_password
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.rds_sg.sg_id]
  environment        = "dev"
  project_name       = "technova"
}
```

## Ambientes

| Aspecto | Dev | Staging |
|---------|-----|---------|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 |
| Subnets públicas | 10.0.1.0/24, 10.0.2.0/24 | 10.1.1.0/24, 10.1.2.0/24 |
| Subnets privadas | 10.0.3.0/24, 10.0.4.0/24 | 10.1.3.0/24, 10.1.4.0/24 |
| EC2 | t2.micro | t2.micro |
| RDS | db.t3.micro | db.t3.micro |
| DB Name | technova_dev | technova_staging |
| Nomes | technova-dev-* | technova-staging-* |

O `main.tf` dos dois ambientes é idêntico. A diferença está só no `terraform.tfvars` de cada um.

## Como usar

### Rodar um ambiente existente

```bash
source aws-creds.sh                        # credenciais do Learner Lab (não versionado)
export TF_VAR_db_password="SenhaForte123"  # alfanumérica; nunca no .tfvars

cd aula-06/environments/dev
terraform init
terraform validate
terraform plan
terraform apply     # opcional, e sempre seguido de terraform destroy
```

As evidências de `validate` e `plan` dos dois ambientes estão em
[`terraform-plan-dev.txt`](terraform-plan-dev.txt) e
[`terraform-plan-staging.txt`](terraform-plan-staging.txt) (19 recursos cada).

### Criar um novo ambiente (ex: prod)

1. Copie a pasta de um ambiente existente:
   ```bash
   cp -r environments/staging environments/prod
   rm -rf environments/prod/.terraform
   ```
2. Ajuste `environments/prod/terraform.tfvars` com um CIDR que não conflite com os outros ambientes:
   ```hcl
   project_name = "technova"
   environment  = "prod"
   vpc_cidr     = "10.2.0.0/16"

   subnets = {
     "public-1"  = { cidr = "10.2.1.0/24", az = "us-east-1a", type = "public" }
     "public-2"  = { cidr = "10.2.2.0/24", az = "us-east-1b", type = "public" }
     "private-1" = { cidr = "10.2.3.0/24", az = "us-east-1a", type = "private" }
     "private-2" = { cidr = "10.2.4.0/24", az = "us-east-1b", type = "private" }
   }

   db_name           = "technova_prod"
   db_instance_class = "db.t3.small"
   ```
3. Rode `terraform init` e `terraform plan` dentro de `environments/prod`.

Nenhum módulo precisa ser alterado. Tudo o que muda entre os ambientes entra por variável.

## Pré-requisitos

- **Terraform >= 1.3**, exigido pelos atributos `optional()` do módulo security-group. O
  provider `hashicorp/aws` fica em `~> 5.0`.
- **AWS CLI** com credenciais válidas. No AWS Academy Learner Lab, use as credenciais de
  *AWS Details → AWS CLI* exportadas via `aws-creds.sh`.
- **Key Pair** existente na região `us-east-1`. O padrão é `vockey`, que já existe no Learner
  Lab. Para outro par, sobrescreva a variável `key_name`.
- Variável de ambiente **`TF_VAR_db_password`** com a senha do banco (só caracteres
  alfanuméricos).
- Em caso de `apply`: suba um ambiente por vez e rode `terraform destroy` ao final. O RDS leva de
  5 a 10 minutos para ficar disponível.
