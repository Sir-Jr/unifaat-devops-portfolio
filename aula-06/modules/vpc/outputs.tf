# modules/vpc/outputs.tf

output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR da VPC"
  value       = aws_vpc.main.cidr_block
}

output "subnet_ids" {
  description = "Mapa de todos os subnet IDs (chave → ID)"
  value       = { for key, subnet in aws_subnet.this : key => subnet.id }
}

output "public_subnet_ids" {
  description = "Lista de IDs das subnets públicas (ordenada pela chave do mapa)"
  value = [
    for key, subnet in aws_subnet.this : subnet.id
    if var.subnets[key].type == "public"
  ]
}

output "private_subnet_ids" {
  description = "Lista de IDs das subnets privadas (ordenada pela chave do mapa)"
  value = [
    for key, subnet in aws_subnet.this : subnet.id
    if var.subnets[key].type == "private"
  ]
}
