.PHONY: help init plan apply destroy validate format clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	cd terraform && terraform init

validate: ## Validate Terraform configuration
	cd terraform && terraform validate

format: ## Format Terraform files
	cd terraform && terraform fmt -recursive

plan: ## Show Terraform plan
	cd terraform && terraform plan

apply: ## Apply Terraform configuration
	cd terraform && terraform apply

destroy: ## Destroy all resources
	cd terraform && terraform destroy

clean: ## Clean Terraform files
	cd terraform && rm -rf .terraform .terraform.lock.hcl terraform.tfstate*

check-scripts: ## Check shell script syntax
	@for script in scripts/*.sh; do \
		echo "Checking $$script..."; \
		bash -n "$$script" && echo "  ✓ OK" || echo "  ✗ Error"; \
	done

check-yaml: ## Validate YAML files
	@python3 -c "import yaml, sys; [yaml.safe_load_all(open(f)) for f in sys.argv[1:]]" kubernetes/*.yaml && echo "✓ All YAML files are valid"

check: check-scripts check-yaml validate ## Run all checks

install-tools: ## Install required tools (Ubuntu/Debian)
	@echo "Installing Azure CLI..."
	@curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
	@echo "Installing Terraform..."
	@wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
	@echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
	@sudo apt-get update && sudo apt-get install -y terraform
	@echo "Installing kubectl..."
	@curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	@sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	@rm kubectl

docs: ## Generate documentation
	@echo "Documentation is available in:"
	@echo "  - README.md"
	@echo "  - docs/quickstart.md"
	@echo "  - docs/architecture.md"
	@echo "  - docs/troubleshooting.md"
	@echo "  - docs/deployment-checklist.md"

setup-ssh: ## Generate SSH key pair
	@if [ ! -f ~/.ssh/id_rsa ]; then \
		ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""; \
		echo "✓ SSH key generated"; \
	else \
		echo "✓ SSH key already exists"; \
	fi

azure-login: ## Login to Azure
	az login
	@echo "✓ Logged in to Azure"
	@echo "Don't forget to set your subscription:"
	@echo "  az account set --subscription '<subscription-id>'"

output: ## Show Terraform outputs
	cd terraform && terraform output

get-kubeconfig: ## Download kubeconfig from control plane
	@CONTROL_PLANE_IP=$$(cd terraform && terraform output -raw control_plane_public_ip); \
	ADMIN_USER=$$(cd terraform && terraform output -raw admin_username 2>/dev/null || echo "azureuser"); \
	scp $$ADMIN_USER@$$CONTROL_PLANE_IP:~/.kube/config ~/.kube/config-azure-k8s; \
	echo "✓ Kubeconfig downloaded to ~/.kube/config-azure-k8s"; \
	echo "Export it with: export KUBECONFIG=~/.kube/config-azure-k8s"

status: ## Check cluster status
	@kubectl get nodes
	@echo ""
	@kubectl get pods --all-namespaces

cost-estimate: ## Estimate monthly cost
	@echo "Monthly cost estimate (US East region):"
	@echo "  - VMs (1x D2s_v3, 2x E2s_v3):  ~$$150-200"
	@echo "  - Storage (Premium SSD):       ~$$3"
	@echo "  - Load Balancer:               ~$$20"
	@echo "  - Blob Storage:                ~$$1"
	@echo "  - Bandwidth:                   ~$$5-20"
	@echo "  ----------------------------------------"
	@echo "  Total:                         ~$$180-250/month"
