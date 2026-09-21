# Infraestrutura TechNova — Aula 04

VPC Multi-AZ + EC2 com Terraform: rede pronta para alta disponibilidade (2 AZs, subnets
públicas/privadas) e uma instância rodando a API TechNova na porta 3000.

## Diagrama da Arquitetura

```
                              Internet
                                 │
                          [Internet Gateway]
                                 │
                    Route Table pública (0.0.0.0/0 → IGW)
                          │              │
        ┌─────────────────┘              └─────────────────┐
        │                                                   │
  AZ us-east-1a                                       AZ us-east-1b
┌─────────────────────────┐                     ┌─────────────────────────┐
│ Subnet pública           │                     │ Subnet pública           │
│ 10.0.1.0/24              │                     │ 10.0.3.0/24              │
│                          │                     │                          │
│  EC2 t2.micro            │                     │  (livre p/ 2ª instância  │
│  SG api (22, 3000)       │                     │   ou Load Balancer)      │
└─────────────────────────┘                     └─────────────────────────┘

┌─────────────────────────┐                     ┌─────────────────────────┐
│ Subnet privada           │                     │ Subnet privada           │
│ 10.0.2.0/24              │                     │ 10.0.4.0/24              │
│ SG db (5432 só da VPC)   │                     │ SG db (5432 só da VPC)   │
│ (sem rota p/ IGW)         │                     │ (sem rota p/ IGW)         │
└─────────────────────────┘                     └─────────────────────────┘

VPC: 10.0.0.0/16
```

## Como usar

### Pré-requisitos

- AWS CLI configurado com credenciais do AWS Academy Learner Lab (`~/.aws/credentials`)
- Terraform >= 1.0
- Chave SSH gerada: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/technova-key -N ""`
- Em CI/CD, sem acesso ao `~/.ssh` local, informe o conteúdo da chave via `TF_VAR_public_key` (tem precedência sobre `public_key_path`)

### Comandos

```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

### Como testar

```bash
export API_IP=$(terraform output -raw ec2_public_ip)

curl http://$API_IP:3000
curl http://$API_IP:3000/health
curl http://$API_IP:3000/orders

ssh -i ~/.ssh/technova-key ec2-user@$API_IP "node --version && aws sts get-caller-identity"
```

### Como destruir

```bash
terraform destroy
```

## Decisões Técnicas

- **Multi-AZ (2 subnets públicas + 2 privadas em `us-east-1a`/`us-east-1b`):** uma única AZ é
  ponto único de falha — se ela cair, a aplicação inteira cai junto. Distribuir subnets em duas
  AZs deixa a infraestrutura pronta para receber um Load Balancer e uma segunda instância no
  futuro sem redesenhar a rede.
- **Separação público/privado:** só o que precisa ser alcançado pela internet (a API) fica em
  subnet com rota para o Internet Gateway. O Security Group do banco (porta 5432) já está
  desenhado para uma subnet privada, restrito ao CIDR interno da VPC (`10.0.0.0/16`) — mesmo sem
  um banco real provisionado nesta entrega, a rede já impõe esse isolamento.
- **`aws_ami` via data source em vez de ID fixo:** o ID de uma AMI muda por região e por
  atualização da Amazon; buscar a mais recente do Amazon Linux 2023 evita que o código quebre
  silenciosamente quando a AMI for descontinuada.
- **Sem credenciais estáticas na instância:** a EC2 não tem `aws_iam_access_key` nenhum — todo
  acesso à AWS de dentro da instância vem de um Instance Profile, com credenciais temporárias
  renovadas automaticamente pela AWS.

### Nota sobre o ambiente — restrição de IAM do AWS Academy

A role `voclabs` do AWS Academy Learner Lab tem Deny explícito para `iam:CreateRole` — a mesma
restrição já documentada na [aula 03](../aula-03/README.md#nota-sobre-o-ambiente). Por isso, ao
contrário do que o roteiro original do exercício sugere, `main.tf` **não cria** `aws_iam_role`,
`aws_iam_role_policy_attachment` nem `aws_iam_instance_profile` próprios — a EC2 referencia
diretamente o `LabInstanceProfile` pré-provisionado pela própria AWS Academy
(`iam_instance_profile = "LabInstanceProfile"`), cuja role (`LabRole`) já aceita
`ec2.amazonaws.com` como principal. Essa é a orientação oficial atualizada do
[Lab Parte 2](../../aula-04/laboratorio-parte2.md) desta aula para ambientes Learner Lab, e o
resultado é o mesmo pedido pelo exercício: `terraform apply` sem erros e a role confirmada via
`aws sts get-caller-identity` dentro da instância (evidência em `evidencia-ssh.txt`).

## Recursos Criados

| Recurso | Nome | Função |
|---|---|---|
| `aws_vpc` | technova-vpc | Rede principal (10.0.0.0/16) |
| `aws_subnet` (x2) | technova-public-subnet-1/2 | Subnets públicas, uma por AZ |
| `aws_subnet` (x2) | technova-private-subnet-1/2 | Subnets privadas, uma por AZ |
| `aws_internet_gateway` | technova-igw | Conecta a VPC à internet |
| `aws_route_table` + `aws_route_table_association` (x2) | technova-public-rt | Rota 0.0.0.0/0 → IGW, associada às 2 subnets públicas |
| `aws_security_group` | technova-api-sg | Libera SSH (22) e API (3000) de qualquer origem |
| `aws_security_group` | technova-db-sg | Libera PostgreSQL (5432) só de dentro da VPC |
| `aws_key_pair` | technova-key | Chave SSH registrada na AWS |
| `data.aws_ami` | amazon_linux | Busca a AMI mais recente do Amazon Linux 2023 |
| `aws_instance` | technova-api-ec2 | EC2 t2.micro rodando a API TechNova na porta 3000, com `iam_instance_profile = "LabInstanceProfile"` (ver nota acima) |
