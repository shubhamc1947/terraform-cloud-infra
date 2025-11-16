output "vpc_id" {
  value = aws_vpc.main.id
}

output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

output "alb_dns" {
  value = aws_lb.main.dns_name
}

output "api_gateway_url" {
  value = aws_apigatewayv2_stage.prod.invoke_url
}

###################################################
# SSH Access Outputs (Using tarmac.pem)
###################################################
output "ssh_to_bastion" {
  description = "SSH command to connect to bastion host"
  value       = "ssh -i tarmac.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "ssh_to_v1_api_via_bastion" {
  description = "SSH command to connect to private API servers via bastion"
  value       = "ssh -i tarmac.pem -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@${aws_instance.v1_api_1.private_ip}"
}
