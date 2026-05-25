.PHONY: infra-bootstrap infra-main infra-turnoff-nat-gateway \
        infra-destroy-bootstrap infra-destroy-main infra-destroy-all \
        bastion-ssh pre-commit

infra-bootstrap:
	@echo "Bootstrap Terraform configuration for Pollflow project"
	cd infra/tf-bootstrap && terraform init
	cd infra/tf-bootstrap && terraform apply -auto-approve

infra-main:
	@echo "Applying Terraform configuration for Pollflow project"
	cd infra/tf-main && terraform init
	cd infra/tf-main && terraform apply -auto-approve

infra-destroy-bootstrap:
	@echo "Destroying Terraform bootstrap infrastructure for Pollflow project"
	cd infra/tf-bootstrap && terraform destroy -auto-approve

infra-destroy-main:
	@echo "Destroying Terraform-managed infrastructure for Pollflow project"
	cd infra/tf-main && terraform destroy -auto-approve

infra-destroy-all: 
	@echo "Destroying all Terraform-managed infrastructure for Pollflow project"
	$(MAKE) infra-destroy-main
	$(MAKE) infra-destroy-bootstrap

infra-turnoff-nat-gateway:
	@echo "Turning off NAT Gateway to save costs"
	cd infra/tf-main && terraform apply -auto-approve -var="nat_gateway_enabled=false"

bastion-ssh:
	@echo "SSH into the bastion host"
	cd infra/tf-main && eval $$(terraform output -raw bastion_ssh_command)

pre-commit:
	@echo "Running pre-commit checks for Terraform"
	./scripts/pre-commit.sh

