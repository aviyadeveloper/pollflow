.PHONY: infra-bootstrap

infra-bootstrap:
	@echo "Bootstrap Terraform configuration for CloudPollPro project"
	cd infra/tf-bootstrap && terraform init
	cd infra/tf-bootstrap && terraform apply

infra-main:
	@echo "Applying Terraform configuration for CloudPollPro project"
	cd infra/terraform && terraform init
	cd infra/terraform && terraform apply

bastion-ssh:
	@echo "SSH into the bastion host"
	cd infra/terraform && eval $$(terraform output -raw bastion_ssh_command)

pre-commit:
	@echo "Running pre-commit checks for Terraform"
	./scripts/pre-commit.sh

