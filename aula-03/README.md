# Aula 03 — Terraform + IAM | Sirlande Martins (6325269)

## Design da Estrutura IAM

Foram criados **2 groups** com separação clara de responsabilidades:

- `6325269-technova-developers` — acesso de leitura a buckets S3 (`technova-*`), mais um Deny
  explícito para ações destrutivas (proteção extra, já que developers não deveriam conseguir
  apagar nada mesmo por engano).
- `6325269-technova-platform-eng` — gerência de EC2 (describe + start/stop restrito a instâncias
  com tag `Project=TechNova`) e leitura/escrita em S3 `technova-*`.

**3 users** distribuídos conforme o cenário da TechNova:

| User | Groups | Motivo |
|---|---|---|
| `6325269-juliana-dev` | developers | Dev sênior, só precisa ler dados |
| `6325269-rafael-platform` | developers + platform-eng | Atua nos dois times |
| `6325269-lucas-intern` | developers | Estagiário — fica só com o acesso mais restrito (leitura + deny explícito), sem entrar em platform-eng |

Cada policy foi desenhada para o mínimo necessário: `s3-read` só tem `GetObject`/`ListBucket`,
`ec2-s3-full` restringe start/stop por `Condition` de tag (não é liberado para qualquer instância
da conta), e `deny-destructive` bloqueia `Delete*`/`Terminate*` independente de qualquer Allow.

## Princípio do Menor Privilégio

O princípio diz: **nunca conceda mais permissão do que o estritamente necessário para a tarefa**.

Dois exemplos aplicados no código:

1. Em vez de anexar `AmazonS3FullAccess` aos developers, criei a policy `6325269-technova-s3-read`
   com apenas `s3:GetObject` e `s3:ListBucket`, restrita a `arn:aws:s3:::technova-*` — não dá pra
   ler/escrever em nenhum outro bucket da conta.
2. Em `ec2-s3-full`, o `start`/`stop` de instâncias só funciona se a instância tiver a tag
   `Project=TechNova` (bloco `condition` em `policies.tf`) — um platform engineer não consegue
   ligar/desligar instâncias de outros projetos na mesma conta.

Se eu tivesse usado `AmazonS3FullAccess` no lugar da policy customizada, qualquer user do grupo
developers conseguiria **apagar qualquer bucket da conta AWS**, não só ler os buckets da TechNova
— o oposto do que a auditoria de segurança pedia.

## Diagrama de Permissões

```
juliana-dev ──┐
rafael-platform ──┼──> Group: developers ──> Policy: technova-s3-read (S3 GetObject/ListBucket)
lucas-intern ──┘                          └─> Policy: technova-deny-destructive (Deny Delete*/Terminate*)

rafael-platform ──> Group: platform-eng ──> Policy: technova-ec2-s3-full
                                             (EC2 describe/start/stop com tag Project=TechNova
                                              + S3 read/write em technova-*)

Role: technova-ec2-role ──assume_role_policy──> Principal: ec2.amazonaws.com
Role: technova-ec2-role ──policy──> technova-ec2-app-data (S3 read/write em technova-app-data-*)
Role: technova-ec2-role ──> Instance Profile: technova-ec2-profile ──> (anexável a uma EC2)
```

## Comandos Utilizados

```bash
terraform init
terraform fmt
terraform validate
terraform plan          # ver terraform-plan-output.txt
terraform apply -auto-approve
```

> **Nota sobre o ambiente:** este projeto foi testado com credenciais do **AWS Academy Learner
> Lab**. O `terraform plan` roda limpo (17 to add, 0 to change, 0 to destroy — evidência em
> `terraform-plan-output.txt`), mas o `terraform apply` retorna `AccessDenied` em
> `iam:CreateRole`, `iam:CreateUser` e `iam:TagPolicy`. Investigando, a role `voclabs` do Learner
> Lab tem **Deny explícito** para ações de escrita em IAM (nem consegui ler o conteúdo das
> policies anexadas — `iam:GetPolicy` também foi negado "with an explicit deny"). É uma restrição
> intencional da sandbox da AWS Academy para esse template de curso, não uma falha no código —
> por isso não há `terraform destroy` a rodar (nada foi de fato criado na conta).

## Reflexão

A criação manual pelo Console é mais rápida pra testar uma coisa pontual, mas não deixa rastro:
se alguém perguntar "por que o Lucas tem acesso de leitura e não de escrita?", a resposta só
existe na memória de quem clicou. Com Terraform, a resposta está no código — `policies.tf` mostra
exatamente que `deny-destructive` bloqueia `Delete*`/`Terminate*` pra todo o grupo developers, e
isso pode ser revisado por outra pessoa antes mesmo de ir pra produção, via Pull Request.

Isso ficou ainda mais claro nesta prática: o `terraform plan` documentou exatamente os 17
recursos que seriam criados, mesmo sem eu conseguir de fato aplicar (a sandbox do AWS Academy
bloqueia criação de IAM por segurança). Numa criação manual pelo Console, eu não teria esse
registro do que *seria* criado — só descobriria as permissões na hora, testando uma por uma.

Pra uma equipe, isso é a diferença entre auditoria real (histórico no Git, revisão por PR, plan
como evidência) e confiar na memória de quem configurou. Terraform é mais seguro não porque é
mais difícil de errar, mas porque o erro fica visível e revisável antes de acontecer.
