# Infraestrutura TechNova — Aula 05

RDS PostgreSQL + Remote State: dados persistentes em subnets privadas, acessados por uma EC2 na
subnet pública, com o state do Terraform protegido em S3 (versionado e criptografado) com locking
via DynamoDB.

## Diagrama da Arquitetura

```
                              Internet
                                 │
                          [Internet Gateway]
                                 │
                    Route Table pública (0.0.0.0/0 → IGW)
                                 │
                           AZ us-east-1a
                    ┌─────────────────────────┐
                    │ Subnet pública           │
                    │ 10.0.1.0/24              │
                    │                          │
                    │  EC2 t2.micro            │
                    │  SG ec2 (22, 3000)       │
                    │  psql client instalado   │
                    └────────────┬─────────────┘
                                 │ porta 5432 (SG rds ← SG ec2)
        ┌────────────────────────┴───────────────────────┐
        │                                                 │
  AZ us-east-1a                                     AZ us-east-1b
┌─────────────────────────┐                     ┌─────────────────────────┐
│ Subnet privada           │                     │ Subnet privada           │
│ 10.0.2.0/24              │                     │ 10.0.4.0/24              │
│ (sem rota p/ IGW)         │                     │ (sem rota p/ IGW)         │
└─────────────────────────┘                     └─────────────────────────┘
              └──────────────── DB Subnet Group ────────────────┘
                                 │
                        RDS PostgreSQL 15
                        db.t3.micro, storage_encrypted
                        publicly_accessible = false

VPC: 10.0.0.0/16

Remote State:
  S3 (versionado + SSE-KMS + Block Public Access) + DynamoDB (lock "LockID")
```

## Como usar

### Pré-requisitos

- AWS CLI configurado com credenciais do AWS Academy Learner Lab (`~/.aws/credentials`)
- Terraform >= 1.0
- Chave SSH gerada: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/technova-key -N ""`

### 1 — Backend de remote state

```bash
cd backend/
terraform init
terraform plan
terraform apply
# Anote os outputs: s3_bucket_name e dynamodb_table_name
```

### 2 — Projeto principal (VPC + RDS + EC2)

Preencha `providers.tf` (bloco `backend "s3"`) com o `s3_bucket_name` obtido acima e crie o
`terraform.tfvars` local (não versionado) a partir do modelo, definindo a senha do banco:

```bash
cp terraform.tfvars.example terraform.tfvars
# edite db_password = "SuaSenhaForte!"
```

Depois:

```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

> A criação do RDS leva 5-10 minutos — é normal o `apply` ficar parado em
> `aws_db_instance.main: Still creating...`.

### Como testar

```bash
export EC2_IP=$(terraform output -raw ec2_public_ip)
export RDS_ADDRESS=$(terraform output -raw rds_address)

ssh -i ~/.ssh/technova-key ec2-user@$EC2_IP "psql -h $RDS_ADDRESS -U technova_admin -d technova -p 5432 -c 'SELECT version();'"
```

### Como destruir

```bash
terraform destroy          # projeto principal
cd backend/
aws s3 rm s3://SEU-BUCKET --recursive   # esvaziar antes de destruir
terraform destroy          # backend
```

## Decisões Técnicas

- **Remote State com S3 + DynamoDB:** protege o `terraform.tfstate` contra perda (versionamento),
  acesso indevido (criptografia + Block Public Access total) e escrita concorrente (lock via
  DynamoDB) — essencial assim que mais de uma pessoa/máquina passa a rodar `terraform apply` sobre
  a mesma infraestrutura.
- **RDS em subnets privadas, sem rota para o IGW:** o banco não tem motivo para ser alcançado pela
  internet. Ficar em subnet privada elimina essa superfície de ataque mesmo que o Security Group
  falhe.
- **Security Group do RDS referenciando o SG do EC2 (em vez de CIDR da VPC):** só a instância que
  roda a API deveria falar com o banco na porta 5432 — restringir a origem ao Security Group do
  EC2 é mais preciso que liberar toda a VPC.
- **`publicly_accessible = false` e `storage_encrypted = true`:** o RDS nunca recebe IP público, e
  os dados em repouso ficam criptografados por padrão.
- **DB Subnet Group com 2 AZs diferentes:** exigência do próprio RDS para o Subnet Group, e deixa
  a infraestrutura pronta para habilitar Multi-AZ no futuro sem redesenhar a rede.

### Nota sobre o ambiente — restrição de SCP do AWS Academy no `aws_s3_bucket`

O provider AWS (`~> 5.0`) faz uma chamada `s3:GetBucketObjectLockConfiguration` automaticamente
sempre que lê o estado do recurso `aws_s3_bucket` (na criação e em todo `plan`/`refresh`
seguinte). No AWS Academy Learner Lab essa chamada é bloqueada por uma Service Control Policy da
organização — a mesma classe de restrição já documentada nas [aula 03](../aula-03/README.md#nota-sobre-o-ambiente)
e [aula 04](../aula-04/README.md#nota-sobre-o-ambiente-restrição-de-iam-do-aws-academy) para IAM.
O bucket é criado normalmente (o `PutBucket` funciona), mas a leitura imediatamente após a criação
falha com `AccessDenied`, marcando o recurso como `tainted`. A solução foi confirmar que o bucket
existia de fato (`aws s3api head-bucket`), rodar `terraform untaint` nele e aplicar os demais
recursos (`versioning`, `server_side_encryption_configuration`, `public_access_block`) com
`terraform plan/apply -refresh=false -target=...`, evitando a chamada bloqueada sem alterar o
resultado final: bucket versionado, criptografado e com Block Public Access total, confirmados via
`aws s3api get-bucket-versioning` / `get-bucket-encryption` / `get-public-access-block`
(evidência em `evidencia-s3-state.txt`).

## Recursos Criados

### Backend (`backend/`)

| Recurso | Nome | Função |
|---|---|---|
| `aws_s3_bucket` | technova-terraform-state-\<sufixo\> | Armazena o `terraform.tfstate` do projeto principal |
| `aws_s3_bucket_versioning` | — | Habilita versionamento do bucket (rollback do state) |
| `aws_s3_bucket_server_side_encryption_configuration` | — | Criptografia SSE-KMS por padrão |
| `aws_s3_bucket_public_access_block` | — | Bloqueia todo acesso público (4 configurações) |
| `aws_dynamodb_table` | technova-terraform-locks | Locking do state (partition key `LockID`) |
| `random_id` | — | Sufixo aleatório para nome único do bucket |

### Projeto principal (`aula-05/`)

| Recurso | Nome | Função |
|---|---|---|
| `aws_vpc` | technova-vpc | Rede principal (10.0.0.0/16) |
| `aws_subnet` (pública) | technova-public-subnet | Subnet da EC2, com rota para o IGW |
| `aws_subnet` (privadas x2) | technova-private-subnet-1/2 | Subnets do DB Subnet Group, em 2 AZs |
| `aws_internet_gateway` | technova-igw | Conecta a VPC à internet |
| `aws_route_table` + `aws_route_table_association` | technova-public-rt | Rota 0.0.0.0/0 → IGW para a subnet pública |
| `aws_security_group` | technova-ec2-sg | Libera SSH (22) e API (3000) |
| `aws_security_group` | technova-rds-sg | Libera PostgreSQL (5432) só do SG do EC2 |
| `aws_key_pair` | technova-key | Chave SSH registrada na AWS |
| `data.aws_ami` | amazon_linux | AMI mais recente do Amazon Linux 2023 |
| `aws_instance` | technova-api | EC2 t2.micro com `psql` client instalado via `user_data.sh` |
| `aws_db_subnet_group` | technova-db-subnet-group | Agrupa as 2 subnets privadas para o RDS |
| `aws_db_instance` | technova-db | PostgreSQL 15 `db.t3.micro`, criptografado, privado |
