# Reflexão — Spec-Driven para EC2 na VPC

## O que o Claude acertou de primeira?
- Acompanhei cada etapa da geração e especifiquei as necessidades do TF com precisão antes de pedir a execução, o que fez o Claude acertar a infraestrutura de primeira.

## O que precisou de correção?
- Nenhuma correção foi necessária no código gerado.

## O user_data.sh gerado funcionou sem ajustes?
- Sim, o `user_data.sh` funcionou sem nenhum ajuste.

## O checklist pegou algum problema de segurança?
- Sim: a tentativa de criar uma IAM Role customizada esbarrou no Deny explícito para `iam:CreateRole` da role `voclabs` no AWS Academy Learner Lab. A solução foi remover os recursos IAM customizados (`aws_iam_role`, `aws_iam_role_policy_attachment`, `aws_iam_instance_profile`) e usar diretamente o instance profile pré-provisionado (`iam_instance_profile = "LabInstanceProfile"`) no `aws_instance`, mantendo a EC2 com credenciais temporárias via `LabRole` e sem access keys hardcoded.

## Comparação com o Lab 1 (manual): qual abordagem foi mais rápida?
- O Spec-Driven foi mais rápido que o Lab 1 manual.

## Em quais partes o Spec-Driven brilhou e em quais foi limitado?
- Brilhou na velocidade e na precisão de execução, resultado direto de especificar bem os requisitos do TF antes de gerar o código.
- Foi limitado nas particularidades do ambiente AWS Academy: o Claude gerou recursos IAM customizados que o Learner Lab bloqueia, exigindo ajuste manual para usar o `LabInstanceProfile` pré-provisionado.
