# Makefile for Terraform Multi-Cloud Kubernetes Platform
# Version: 2.0.0

.PHONY: help install-dev-tools verify-setup clean test security-scan docs-generate

# Default target
.DEFAULT_GOAL := help

# Variables
TERRAFORM_VERSION := 1.6.6
KUBECTL_VERSION := 1.28.0
HELM_VERSION := 3.12.0
CLOUD_PROVIDER ?= digitalocean
ENVIRONMENT ?= dev
TF_VAR_FILE ?= terraform.tfvars

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Help target
help: ## Show this help message
	@echo "$(BLUE)Terraform Multi-Cloud Kubernetes Platform$(NC)"
	@echo "$(BLUE)===========================================$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Examples:$(NC)"
	@echo "  make install-dev-tools           # Install development dependencies"
	@echo "  make test CLOUD_PROVIDER=azure   # Run tests for Azure"
	@echo "  make deploy ENV=production       # Deploy to production"
	@echo ""

## Development Setup
install-dev-tools: ## Install development tools and dependencies
	@echo "$(BLUE)Installing development tools...$(NC)"
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)Installing Terraform...$(NC)"; \
		curl -fsSL https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_$$(uname -s | tr '[:upper:]' '[:lower:]')_amd64.zip -o terraform.zip; \
		unzip terraform.zip; sudo mv terraform /usr/local/bin/; rm terraform.zip; }
	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)Installing kubectl...$(NC)"; \
		curl -LO "https://dl.k8s.io/release/v$(KUBECTL_VERSION)/bin/$$(uname -s | tr '[:upper:]' '[:lower:]')/amd64/kubectl"; \
		chmod +x kubectl; sudo mv kubectl /usr/local/bin/; }
	@command -v helm >/dev/null 2>&1 || { echo "$(RED)Installing Helm...$(NC)"; \
		curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3; \
		chmod 700 get_helm.sh; ./get_helm.sh; rm get_helm.sh; }
	@command -v pre-commit >/dev/null 2>&1 || { echo "$(RED)Installing pre-commit...$(NC)"; pip install pre-commit; }
	@command -v terraform-docs >/dev/null 2>&1 || { echo "$(RED)Installing terraform-docs...$(NC)"; \
		curl -sSLo terraform-docs.tar.gz https://terraform-docs.io/dl/v0.16.0/terraform-docs-v0.16.0-$$(uname -s | tr '[:upper:]' '[:lower:]')-amd64.tar.gz; \
		tar -xzf terraform-docs.tar.gz; sudo mv terraform-docs /usr/local/bin/; rm terraform-docs.tar.gz; }
	@command -v tflint >/dev/null 2>&1 || { echo "$(RED)Installing tflint...$(NC)"; \
		curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash; }
	@command -v checkov >/dev/null 2>&1 || { echo "$(RED)Installing checkov...$(NC)"; pip install checkov; }
	@command -v tfsec >/dev/null 2>&1 || { echo "$(RED)Installing tfsec...$(NC)"; \
		curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash; }
	@echo "$(GREEN)Development tools installed successfully!$(NC)"

verify-setup: ## Verify development environment setup
	@echo "$(BLUE)Verifying development environment...$(NC)"
	@terraform version
	@kubectl version --client
	@helm version
	@pre-commit --version
	@terraform-docs --version
	@tflint --version
	@checkov --version
	@tfsec --version
	@echo "$(GREEN)Environment verification completed!$(NC)"

## Terraform Operations
terraform-init: ## Initialize Terraform for specified cloud provider and environment
	@echo "$(BLUE)Initializing Terraform for $(CLOUD_PROVIDER) $(ENVIRONMENT)...$(NC)"
	@cd terraform/environments/$(ENVIRONMENT)/$(CLOUD_PROVIDER) && terraform init

terraform-plan: ## Run Terraform plan
	@echo "$(BLUE)Running Terraform plan for $(CLOUD_PROVIDER) $(ENVIRONMENT)...$(NC)"
	@cd terraform/environments/$(ENVIRONMENT)/$(CLOUD_PROVIDER) && \
		terraform plan -var-file="$(TF_VAR_FILE)" -out=tfplan

terraform-apply: ## Apply Terraform configuration
	@echo "$(BLUE)Applying Terraform configuration for $(CLOUD_PROVIDER) $(ENVIRONMENT)...$(NC)"
	@cd terraform/environments/$(ENVIRONMENT)/$(CLOUD_PROVIDER) && \
		terraform apply -var-file="$(TF_VAR_FILE)" -auto-approve

terraform-destroy: ## Destroy Terraform infrastructure
	@echo "$(RED)Destroying Terraform infrastructure for $(CLOUD_PROVIDER) $(ENVIRONMENT)...$(NC)"
	@read -p "Are you sure you want to destroy $(CLOUD_PROVIDER) $(ENVIRONMENT)? [y/N] " confirm && \
		[ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || exit 1
	@cd terraform/environments/$(ENVIRONMENT)/$(CLOUD_PROVIDER) && \
		terraform destroy -var-file="$(TF_VAR_FILE)" -auto-approve

terraform-validate: ## Validate all Terraform configurations
	@echo "$(BLUE)Validating Terraform configurations...$(NC)"
	@find terraform/ -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do \
		echo "Validating $$dir"; \
		cd "$$dir" && terraform init -backend=false >/dev/null 2>&1 && terraform validate; \
		cd - >/dev/null; \
	done
	@echo "$(GREEN)Terraform validation completed!$(NC)"

terraform-fmt: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	@terraform fmt -recursive terraform/
	@echo "$(GREEN)Terraform formatting completed!$(NC)"

terraform-fmt-check: ## Check Terraform file formatting
	@echo "$(BLUE)Checking Terraform file formatting...$(NC)"
	@terraform fmt -check -recursive terraform/

## Testing
test: test-unit test-integration ## Run all tests
	@echo "$(GREEN)All tests completed!$(NC)"

test-unit: terraform-validate terraform-fmt-check yaml-lint shell-check ## Run unit tests
	@echo "$(BLUE)Running unit tests...$(NC)"
	@echo "$(GREEN)Unit tests completed!$(NC)"

test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@bash tests/integration/cluster-health.sh
	@bash tests/integration/connectivity-test.sh
	@echo "$(GREEN)Integration tests completed!$(NC)"

test-digitalocean: ## Run tests specifically for DigitalOcean
	@echo "$(BLUE)Running DigitalOcean-specific tests...$(NC)"
	@CLOUD_PROVIDER=digitalocean bash tests/integration/cloud-specific-tests.sh
	@echo "$(GREEN)DigitalOcean tests completed!$(NC)"

test-azure: ## Run tests specifically for Azure
	@echo "$(BLUE)Running Azure-specific tests...$(NC)"
	@CLOUD_PROVIDER=azure bash tests/integration/cloud-specific-tests.sh
	@echo "$(GREEN)Azure tests completed!$(NC)"

test-aws: ## Run tests specifically for AWS
	@echo "$(BLUE)Running AWS-specific tests...$(NC)"
	@CLOUD_PROVIDER=aws bash tests/integration/cloud-specific-tests.sh
	@echo "$(GREEN)AWS tests completed!$(NC)"

yaml-lint: ## Lint YAML files
	@echo "$(BLUE)Linting YAML files...$(NC)"
	@find . -name "*.yaml" -o -name "*.yml" | grep -v .git | xargs yamllint -c .yamllint.yml
	@echo "$(GREEN)YAML linting completed!$(NC)"

shell-check: ## Check shell scripts
	@echo "$(BLUE)Checking shell scripts...$(NC)"
	@find . -name "*.sh" | grep -v .git | xargs shellcheck
	@echo "$(GREEN)Shell script checking completed!$(NC)"

## Security
security-scan: checkov tfsec trivy ## Run all security scans
	@echo "$(GREEN)Security scanning completed!$(NC)"

checkov: ## Run Checkov security scan
	@echo "$(BLUE)Running Checkov security scan...$(NC)"
	@checkov -d terraform/ --framework terraform --quiet

tfsec: ## Run tfsec security scan
	@echo "$(BLUE)Running tfsec security scan...$(NC)"
	@tfsec terraform/ --no-colour

trivy: ## Run Trivy security scan
	@echo "$(BLUE)Running Trivy security scan...$(NC)"
	@command -v trivy >/dev/null 2>&1 || { echo "$(YELLOW)Trivy not installed, skipping...$(NC)"; exit 0; }
	@trivy fs terraform/

## Documentation
docs-generate: ## Generate documentation for Terraform modules
	@echo "$(BLUE)Generating documentation...$(NC)"
	@find terraform/modules -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do \
		echo "Generating docs for $dir"; \
		terraform-docs markdown table --output-file README.md "$dir"; \
	done
	@echo "$(GREEN)Documentation generation completed!$(NC)"

docs-validate: ## Validate documentation
	@echo "$(BLUE)Validating documentation...$(NC)"
	@markdownlint README.md CONTRIBUTING.md SECURITY.md docs/
	@echo "$(GREEN)Documentation validation completed!$(NC)"

## Deployment
deploy: terraform-init terraform-plan terraform-apply get-kubeconfig verify-cluster ## Deploy infrastructure
	@echo "$(GREEN)Deployment completed for $(CLOUD_PROVIDER) $(ENVIRONMENT)!$(NC)"

bootstrap: ## Bootstrap backend storage for Terraform state
	@echo "$(BLUE)Bootstrapping backend storage for $(CLOUD_PROVIDER)...$(NC)"
	@cd terraform/modules/bootstrap/$(CLOUD_PROVIDER) && \
		terraform init && \
		terraform apply -var="environment=$(ENVIRONMENT)" -auto-approve
	@echo "$(GREEN)Bootstrap completed!$(NC)"

get-kubeconfig: ## Get kubeconfig for the deployed cluster
	@echo "$(BLUE)Getting kubeconfig for $(CLOUD_PROVIDER) $(ENVIRONMENT)...$(NC)"
	@cd terraform/environments/$(ENVIRONMENT)/$(CLOUD_PROVIDER) && \
		terraform output -raw kubeconfig > ~/.kube/config-$(CLOUD_PROVIDER)-$(ENVIRONMENT)
	@echo "$(GREEN)Kubeconfig saved to ~/.kube/config-$(CLOUD_PROVIDER)-$(ENVIRONMENT)$(NC)"
	@echo "$(YELLOW)Set KUBECONFIG: export KUBECONFIG=~/.kube/config-$(CLOUD_PROVIDER)-$(ENVIRONMENT)$(NC)"

verify-cluster: ## Verify cluster is healthy
	@echo "$(BLUE)Verifying cluster health...$(NC)"
	@kubectl get nodes
	@kubectl get pods --all-namespaces
	@echo "$(GREEN)Cluster verification completed!$(NC)"

install-monitoring: ## Install monitoring stack (Prometheus, Grafana)
	@echo "$(BLUE)Installing monitoring stack...$(NC)"
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo add grafana https://grafana.github.io/helm-charts
	@helm repo update
	@kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
	@helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
		--namespace monitoring \
		--values monitoring/prometheus/values.yaml
	@echo "$(GREEN)Monitoring stack installed!$(NC)"

## Maintenance
clean: ## Clean up temporary files and caches
	@echo "$(BLUE)Cleaning up...$(NC)"
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.tfplan" -delete 2>/dev/null || true
	@find . -name "*.tfstate.backup" -delete 2>/dev/null || true
	@find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@rm -rf .pytest_cache/ .coverage htmlcov/ 2>/dev/null || true
	@echo "$(GREEN)Cleanup completed!$(NC)"

upgrade-terraform: ## Upgrade Terraform providers
	@echo "$(BLUE)Upgrading Terraform providers...$(NC)"
	@find terraform/ -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do \
		echo "Upgrading providers in $dir"; \
		cd "$dir" && terraform init -upgrade; \
		cd - >/dev/null; \
	done
	@echo "$(GREEN)Terraform providers upgraded!$(NC)"

## Multi-Cloud Operations
deploy-all: ## Deploy to all supported cloud providers
	@echo "$(BLUE)Deploying to all cloud providers...$(NC)"
	@$(MAKE) deploy CLOUD_PROVIDER=digitalocean
	@$(MAKE) deploy CLOUD_PROVIDER=azure
	@$(MAKE) deploy CLOUD_PROVIDER=aws
	@echo "$(GREEN)Multi-cloud deployment completed!$(NC)"

destroy-all: ## Destroy infrastructure in all cloud providers
	@echo "$(RED)Destroying infrastructure in all cloud providers...$(NC)"
	@read -p "Are you sure you want to destroy ALL infrastructure? [y/N] " confirm && \
		[ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || exit 1
	@$(MAKE) terraform-destroy CLOUD_PROVIDER=digitalocean
	@$(MAKE) terraform-destroy CLOUD_PROVIDER=azure
	@$(MAKE) terraform-destroy CLOUD_PROVIDER=aws
	@echo "$(GREEN)Multi-cloud destruction completed!$(NC)"

cost-estimate: ## Estimate costs for all cloud providers
	@echo "$(BLUE)Estimating costs...$(NC)"
	@command -v infracost >/dev/null 2>&1 || { echo "$(YELLOW)Infracost not installed, install it for cost estimation$(NC)"; exit 1; }
	@infracost breakdown --path terraform/environments/$(ENVIRONMENT)/digitalocean
	@infracost breakdown --path terraform/environments/$(ENVIRONMENT)/azure
	@infracost breakdown --path terraform/environments/$(ENVIRONMENT)/aws
	@echo "$(GREEN)Cost estimation completed!$(NC)"

## CI/CD
pre-commit-all: ## Run all pre-commit checks
	@echo "$(BLUE)Running all pre-commit checks...$(NC)"
	@pre-commit run --all-files
	@echo "$(GREEN)Pre-commit checks completed!$(NC)"

ci-test: ## Run CI test suite
	@echo "$(BLUE)Running CI test suite...$(NC)"
	@$(MAKE) terraform-validate
	@$(MAKE) terraform-fmt-check
	@$(MAKE) security-scan
	@$(MAKE) test-unit
	@echo "$(GREEN)CI test suite completed!$(NC)"

release-prepare: ## Prepare for release
	@echo "$(BLUE)Preparing for release...$(NC)"
	@$(MAKE) clean
	@$(MAKE) docs-generate
	@$(MAKE) ci-test
	@echo "$(GREEN)Release preparation completed!$(NC)"

## Development Helpers
dev-setup: install-dev-tools ## Complete development environment setup
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@pre-commit install
	@cp .env.example .env
	@echo "$(YELLOW)Please edit .env with your cloud credentials$(NC)"
	@$(MAKE) verify-setup
	@echo "$(GREEN)Development environment setup completed!$(NC)"

quick-test: terraform-validate terraform-fmt-check ## Quick validation tests
	@echo "$(GREEN)Quick tests completed!$(NC)"

status: ## Show status of all environments
	@echo "$(BLUE)Environment Status:$(NC)"
	@for env in dev staging production; do \
		for cloud in digitalocean azure aws; do \
			if [ -d "terraform/environments/$env/$cloud" ]; then \
				echo "$(YELLOW)$cloud ($env):$(NC)"; \
				cd "terraform/environments/$env/$cloud" && \
					terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[].address' 2>/dev/null || echo "  No state found"; \
				cd - >/dev/null; \
			fi; \
		done; \
	done

## Troubleshooting
debug-terraform: ## Debug Terraform issues
	@echo "$(BLUE)Terraform Debug Information:$(NC)"
	@echo "Terraform version: $(terraform version)"
	@echo "Current directory: $(pwd)"
	@echo "Cloud provider: $(CLOUD_PROVIDER)"
	@echo "Environment: $(ENVIRONMENT)"
	@cd terraform/environments/$(ENVIRONMENT)/$(CLOUD_PROVIDER) && \
		terraform show -json 2>/dev/null | jq '.terraform_version' || echo "No state file found"

debug-kubectl: ## Debug kubectl connectivity
	@echo "$(BLUE)Kubectl Debug Information:$(NC)"
	@kubectl version --client
	@kubectl cluster-info || echo "No cluster connection"
	@kubectl get nodes || echo "Cannot get nodes"
	@kubectl get namespaces || echo "Cannot get namespaces"

logs-monitoring: ## Show monitoring stack logs
	@echo "$(BLUE)Monitoring Stack Logs:$(NC)"
	@kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=50
	@kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=50

## Performance
benchmark: ## Run performance benchmarks
	@echo "$(BLUE)Running performance benchmarks...$(NC)"
	@bash tests/performance/terraform-performance.sh
	@bash tests/performance/cluster-performance.sh
	@echo "$(GREEN)Performance benchmarks completed!$(NC)"

## Environment Management
list-environments: ## List all available environments
	@echo "$(BLUE)Available Environments:$(NC)"
	@find terraform/environments -mindepth 2 -maxdepth 2 -type d | \
		sed 's|terraform/environments/||' | \
		sort | \
		awk -F/ '{print "  " $2 " (" $1 ")"}'

switch-context: ## Switch kubectl context to specified cluster
	@echo "$(BLUE)Switching kubectl context to $(CLOUD_PROVIDER) $(ENVIRONMENT)...$(NC)"
	@export KUBECONFIG=~/.kube/config-$(CLOUD_PROVIDER)-$(ENVIRONMENT)
	@kubectl config current-context
	@echo "$(GREEN)Context switched to $(CLOUD_PROVIDER) $(ENVIRONMENT)$(NC)"
	@echo "$(YELLOW)Run: export KUBECONFIG=~/.kube/config-$(CLOUD_PROVIDER)-$(ENVIRONMENT)$(NC)"

## Backup and Recovery
backup-state: ## Backup Terraform state files
	@echo "$(BLUE)Backing up Terraform state files...$(NC)"
	@mkdir -p backups/$(date +%Y%m%d-%H%M%S)
	@find terraform/environments -name "terraform.tfstate" -exec cp {} backups/$(date +%Y%m%d-%H%M%S)/ \;
	@echo "$(GREEN)State files backed up!$(NC)"

restore-state: ## Restore Terraform state from backup (requires BACKUP_DIR)
	@echo "$(BLUE)Restoring Terraform state from $(BACKUP_DIR)...$(NC)"
	@test -n "$(BACKUP_DIR)" || { echo "$(RED)BACKUP_DIR not specified$(NC)"; exit 1; }
	@test -d "$(BACKUP_DIR)" || { echo "$(RED)Backup directory not found$(NC)"; exit 1; }
	@cp $(BACKUP_DIR)/* terraform/environments/$(ENVIRONMENT)/$(CLOUD_PROVIDER)/
	@echo "$(GREEN)State files restored!$(NC)"

## Monitoring and Alerts
check-alerts: ## Check active alerts in monitoring
	@echo "$(BLUE)Checking active alerts...$(NC)"
	@kubectl get prometheusrules -n monitoring
	@curl -s http://localhost:9093/api/v1/alerts 2>/dev/null | jq '.data[] | select(.state=="firing")' || \
		echo "AlertManager not accessible or no alerts"

metrics: ## Show cluster metrics
	@echo "$(BLUE)Cluster Metrics:$(NC)"
	@kubectl top nodes || echo "Metrics server not available"
	@kubectl top pods --all-namespaces | head -20 || echo "Pod metrics not available"

## Update and Maintenance
update-deps: ## Update all dependencies
	@echo "$(BLUE)Updating dependencies...$(NC)"
	@pre-commit autoupdate
	@$(MAKE) upgrade-terraform
	@echo "$(GREEN)Dependencies updated!$(NC)"

health-check: ## Comprehensive health check
	@echo "$(BLUE)Running comprehensive health check...$(NC)"
	@$(MAKE) verify-cluster
	@$(MAKE) check-alerts
	@$(MAKE) metrics
	@bash tests/integration/cluster-health.sh
	@echo "$(GREEN)Health check completed!$(NC)"

## Help and Information
version: ## Show version information
	@echo "$(BLUE)Version Information:$(NC)"
	@echo "Terraform: $(terraform version | head -1)"
	@echo "kubectl: $(kubectl version --client --short 2>/dev/null | head -1)"
	@echo "Helm: $(helm version --short 2>/dev/null)"
	@echo "Platform: $(uname -s) $(uname -m)"

info: ## Show project information
	@echo "$(BLUE)Terraform Multi-Cloud Kubernetes Platform$(NC)"
	@echo "$(BLUE)=========================================$(NC)"
	@echo ""
	@echo "$(GREEN)Supported Cloud Providers:$(NC)"
	@echo "  • DigitalOcean (DOKS)"
	@echo "  • Microsoft Azure (AKS)" 
	@echo "  • Amazon Web Services (EKS)"
	@echo ""
	@echo "$(GREEN)Supported Environments:$(NC)"
	@echo "  • Development (dev)"
	@echo "  • Staging (staging)"
	@echo "  • Production (production)"
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC)"
	@echo "  1. make dev-setup"
	@echo "  2. Edit .env with your credentials"
	@echo "  3. make deploy CLOUD_PROVIDER=digitalocean"
	@echo ""