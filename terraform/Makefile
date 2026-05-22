dev-apply:
	git pull
	rm -f .terraform/terraform.tfstate
	terraform init -backend-config=environments/dev/state.tfvars
	terraform apply -auto-approve -var-file=environments/dev/main.tfvars

dev-destroy:
	git pull
	rm -f .terraform/terraform.tfstate
	terraform init -backend-config=environments/dev/state.tfvars
	terraform destroy -auto-approve -var-file=environments/dev/main.tfvars

dev-plan:
	terraform init -backend-config=environments/dev/state.tfvars
	terraform plan -var-file=environments/dev/main.tfvars
