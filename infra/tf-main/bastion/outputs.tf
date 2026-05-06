output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_eip.bastion_eip.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host"
  value       = aws_instance.bastion.id
}

output "key_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.bastion_key.key_name
}

output "private_key_path" {
  description = "Path to the private SSH key file"
  value       = local_file.private_key.filename
}

output "ssh_command" {
  description = "Ready-to-use SSH command to connect to bastion"
  value       = "ssh -t -i ${local_file.private_key.filename} ubuntu@${aws_eip.bastion_eip.public_ip}"
}

output "connection_details" {
  description = "Complete connection details for the bastion host"
  value = {
    public_ip        = aws_eip.bastion_eip.public_ip
    private_key_path = local_file.private_key.filename
    username         = "ubuntu"
    ssh_command      = "ssh -t -i ${local_file.private_key.filename} ubuntu@${aws_eip.bastion_eip.public_ip}"
  }
}
