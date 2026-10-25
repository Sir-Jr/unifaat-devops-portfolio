output "instance_id" {
  description = "ID da EC2 de deploy"
  value       = aws_instance.api.id
}

output "public_ip" {
  description = "IP público atual (muda quando o Lab reinicia a EC2; o cd.yml busca pela tag)"
  value       = aws_instance.api.public_ip
}

output "health_url" {
  description = "Endpoint de health check da API"
  value       = "http://${aws_instance.api.public_ip}:${var.app_port}/health"
}

output "security_group_id" {
  description = "Security Group da API"
  value       = aws_security_group.technova_api.id
}
