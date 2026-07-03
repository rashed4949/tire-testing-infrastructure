output "jenkins_url" {
  description = "Jenkins web interface"
  value       = "http://${module.ec2.jenkins_public_ip}:8080"
}

output "grafana_url" {
  value = "http://${module.ec2.monitoring_public_ip}:3000"
}

output "prometheus_url" {
  value = "http://${module.ec2.monitoring_public_ip}:9090"
}

output "ecr_url" {
  description = "Use this in Jenkinsfile as ECR variable"
  value       = module.ecr.repository_url
}

output "jenkins_ssh" {
  description = "Command to SSH into Jenkins EC2"
  value       = "ssh -i ~/.ssh/thesis-key.pem ubuntu@${module.ec2.jenkins_public_ip}"
}

output "prod_ssh" {
  value = "ssh -i ~/.ssh/thesis-key.pem ubuntu@${module.ec2.prod_hybrid_public_ip}"
}

output "monitoring_ssh" {
  value = "ssh -i ~/.ssh/thesis-key.pem ubuntu@${module.ec2.monitoring_public_ip}"
}

output "prod_private_ip" {
  description = "Use in Ansible inventory"
  value       = module.ec2.prod_hybrid_private_ip
}

output "jenkins_private_ip" {
  value = module.ec2.jenkins_private_ip
}

/*output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_db_url" {
  description = "JDBC URL — paste this into Jenkins credentials"
  value       = module.rds.db_url
}*/

output "aws_account_id" {
  description = "Your AWS account ID — needed in Jenkinsfile"
  value       = data.aws_caller_identity.current.account_id
}
