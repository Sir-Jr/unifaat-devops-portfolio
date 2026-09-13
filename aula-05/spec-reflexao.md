# Reflexão — Spec-Driven para RDS e Remote State

## O que o Claude acertou de primeira?
- A estrutura completa do backend (S3 + DynamoDB) e do projeto principal (VPC, RDS, EC2), sem
  nenhum erro de sintaxe.

## O que precisou de correção?
- Nenhuma correção de código foi necessária. A única intervenção não foi no `.tf`, mas
  operacional: contornar um bloqueio de ambiente do AWS Academy (ver checklist de segurança
  abaixo).

## O backend (S3 + DynamoDB) funcionou sem ajustes?
- Sim, o código gerado para o backend funcionou como estava. O ajuste necessário foi de
  execução (`terraform untaint` + `apply -refresh=false -target=...`), não uma mudança no código.

## O checklist pegou algum problema de segurança?
- Sim: o provider AWS (`~> 5.0`) faz uma chamada `s3:GetBucketObjectLockConfiguration`
  automaticamente ao ler o estado do recurso `aws_s3_bucket`, e essa chamada esbarra num Deny
  explícito de Service Control Policy da organização do AWS Academy Learner Lab — mesma classe de
  restrição já vista na Aula 04 para IAM. O bucket é criado normalmente; a leitura imediatamente
  após a criação falha com `AccessDenied`, marcando o recurso como `tainted`. A solução foi
  confirmar que o bucket existia de fato (`aws s3api head-bucket`), rodar `terraform untaint` e
  aplicar os demais recursos com `-refresh=false -target=...`, sem alterar o resultado final:
  bucket versionado, criptografado e com Block Public Access total.

## Comparação com o Lab 1 (manual): qual abordagem foi mais rápida?
- O Lab 1 (RDS, manual, seguindo o roteiro passo a passo) levou cerca de 40 minutos. O Lab 2
  (Remote State, Spec-Driven com o Claude) foi mais rápido que o Lab 1, sem erros de sintaxe no
  código gerado.

## Em quais partes o Spec-Driven brilhou e em quais foi limitado?
- Brilhou na velocidade e na ausência de erros de sintaxe — o código do backend e do projeto
  principal saiu correto sem retrabalho.
- Foi limitado pelas particularidades do ambiente AWS Academy: assim como na Aula 04 (IAM), a
  Aula 05 esbarrou numa restrição de SCP (agora em S3) que nenhuma abordagem — manual ou
  spec-driven — evitaria sozinha, exigindo intervenção manual de qualquer forma.

## Atenção à leitura dos requisitos
- Depois de entregar o PR, o bot avaliador apontou como ressalva a "falta" de um `main.tf` no
  projeto, seguindo um exemplo genérico de outro material da aula. O TF.md da Aula 05, porém,
  pede literalmente o backend `s3` configurado no `providers.tf` — nome diferente do sugerido
  pelo bot. O código estava certo desde o início; o problema foi uma leitura automática que não
  bateu com o enunciado real da entrega.
- Esse episódio reforça a importância de ler as orientações do TF com atenção antes de aceitar
  qualquer sugestão de correção, seja de um checker automático ou de outra fonte — vou me atentar
  mais a isso nas próximas entregas.
