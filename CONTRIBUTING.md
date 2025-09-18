# Contributing to Terraform Multi-Cloud Kubernetes Platform

🎉 Thank you for your interest in contributing to our multi-cloud Kubernetes platform! We welcome contributions from the community and are excited to collaborate with you.

## 📋 Table of Contents

- [Code of Conduct](#-code-of-conduct)
- [Getting Started](#-getting-started)
- [Development Workflow](#-development-workflow)
- [Contributing Guidelines](#-contributing-guidelines)
- [Testing](#-testing)
- [Documentation](#-documentation)
- [Pull Request Process](#-pull-request-process)
- [Issue Guidelines](#-issue-guidelines)
- [Community](#-community)

## 📜 Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to `conduct@your-domain.com`.

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

```bash
# Required tools
terraform >= 1.6.0
kubectl >= 1.28.0
helm >= 3.12.0
git >= 2.40.0
make >= 4.3

# Recommended tools
docker >= 24.0.0
pre-commit >= 3.0.0
tflint >= 0.47.0
terraform-docs >= 0.16.0
```

### Development Environment Setup

1. **Fork and Clone**
   ```bash
   # Fork the repository on GitHub
   # Clone your fork
   git clone https://github.com/YOUR_USERNAME/terraform-multicloud-kubernetes.git
   cd terraform-multicloud-kubernetes
   
   # Add upstream remote
   git remote add upstream https://github.com/animesh-mukherjee-devops/terraform-multicloud-kubernetes.git
   ```

2. **Install Development Dependencies**
   ```bash
   # Install pre-commit hooks
   pre-commit install
   
   # Install additional tools
   make install-dev-tools
   
   # Verify installation
   make verify-setup
   ```

3. **Configure Development Environment**
   ```bash
   # Copy example configuration
   cp .env.example .env
   
   # Edit with your credentials (never commit this file)
   nano .env
   
   # Source environment variables
   source .env
   ```

## 🔄 Development Workflow

### Branching Strategy

We use Git Flow with the following branch structure:

- **`main`**: Production-ready code
- **`develop`**: Integration branch for features
- **`feature/*`**: Feature development branches
- **`bugfix/*`**: Bug fix branches
- **`hotfix/*`**: Emergency fixes for production
- **`release/*`**: Release preparation branches

### Creating a Feature Branch

```bash
# Ensure you're on develop and up to date
git checkout develop
git pull upstream develop

# Create and checkout feature branch
git checkout -b feature/your-feature-name

# Make your changes
# ...

# Commit with conventional commit format
git commit -m "feat: add support for AWS EKS Fargate profiles"
```

### Conventional Commits

We use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Types:
- **feat**: New features
- **fix**: Bug fixes
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks
- **ci**: CI/CD changes

Examples:
```bash
git commit -m "feat(aws): add EKS Fargate support"
git commit -m "fix(azure): resolve AKS node pool scaling issue"
git commit -m "docs: update installation guide for macOS"
git commit -m "test: add integration tests for DigitalOcean module"
```

## 📝 Contributing Guidelines

### What We're Looking For

We welcome contributions in the following areas:

1. **🆕 New Features**
   - Additional cloud provider support
   - Enhanced monitoring and observability
   - Security improvements
   - Cost optimization features

2. **🐛 Bug Fixes**
   - Infrastructure provisioning issues
   - Configuration problems
   - Documentation errors

3. **📚 Documentation**
   - Usage examples
   - Troubleshooting guides
   - Architecture documentation
   - Best practices

4. **🧪 Testing**
   - Unit tests for Terraform modules
   - Integration tests
   - End-to-end tests
   - Performance tests

### Code Standards

#### Terraform Code Standards

```hcl
# Good: Use descriptive resource names
resource "digitalocean_kubernetes_cluster" "main" {
  name    = var.cluster_name
  region  = var.region
  version = data.digitalocean_kubernetes_versions.available.latest_version
  
  # Always include tags/labels
  tags = local.common_tags
}

# Good: Use variables for configuration
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.cluster_name))
    error_message = "Cluster name must be lowercase alphanumeric with hyphens."
  }
}

# Good: Provide comprehensive outputs
output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = digitalocean_kubernetes_cluster.main.endpoint
  sensitive   = false
}
```

#### File Organization

```
terraform/modules/kubernetes/digitalocean/
├── main.tf          # Primary resources
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── versions.tf      # Provider requirements
├── locals.tf        # Local values (if needed)
└── README.md        # Module documentation
```

#### Documentation Standards

- **Module Documentation**: Every module must have a README.md
- **Variable Documentation**: All variables must have descriptions
- **Output Documentation**: All outputs must have descriptions
- **Example Usage**: Include practical examples

#### Security Guidelines

- **No Hardcoded Secrets**: Never commit secrets or credentials
- **Least Privilege**: Follow principle of least privilege
- **Security Scanning**: All code must pass security scans
- **Validation**: Include input validation for all variables

### Testing Requirements

#### Unit Tests

```bash
# Run Terraform validation
make terraform-validate

# Run linting
make terraform-lint

# Check formatting
make terraform-fmt-check
```

#### Integration Tests

```bash
# Run integration tests (requires cloud credentials)
make test-integration

# Test specific cloud provider
make test-digitalocean
make test-azure
make test-aws
```

#### Security Tests

```bash
# Run security scans
make security-scan

# Run specific security tools
make checkov
make tfsec
make trivy
```

## 🧪 Testing

### Running Tests Locally

```bash
# Install test dependencies
make install-test-deps

# Run all tests
make test

# Run specific test suites
make test-unit
make test-integration
make test-security

# Run tests for specific cloud provider
make test-do ENV=dev
make test-azure ENV=staging
make test-aws ENV=production
```

### Test Structure

```
tests/
├── unit/                    # Unit tests
│   ├── terraform-validate/  # Terraform validation tests
│   ├── yaml-lint/          # YAML linting tests
│   └── shell-check/        # Shell script tests
├── integration/            # Integration tests
│   ├── cluster-creation/   # Cluster creation tests
│   ├── monitoring-stack/   # Monitoring deployment tests
│   └── security-policies/  # Security configuration tests
└── e2e/                    # End-to-end tests
    ├── multi-cloud/        # Multi-cloud scenarios
    └── disaster-recovery/  # DR testing
```

### Adding New Tests

1. **Create Test File**
   ```bash
   # For unit tests
   touch tests/unit/test-new-feature.sh
   
   # For integration tests
   touch tests/integration/test-new-integration.sh
   ```

2. **Write Test**
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   # Test description
   echo "Testing new feature..."
   
   # Test implementation
   # ...
   
   echo "✅ Test passed"
   ```

3. **Add to Test Suite**
   ```makefile
   # Add to Makefile
   test-new-feature:
       @bash tests/unit/test-new-feature.sh
   
   test-unit: test-new-feature test-existing-features
   ```

## 📚 Documentation

### Documentation Requirements

All contributions must include appropriate documentation:

1. **Code Comments**: Inline comments for complex logic
2. **README Updates**: Update relevant README files
3. **Module Documentation**: Terraform module documentation
4. **Example Updates**: Update or add usage examples

### Generating Documentation

```bash
# Generate Terraform documentation
make docs-generate

# Update module documentation
terraform-docs markdown table --output-file README.md ./terraform/modules/kubernetes/digitalocean/

# Validate documentation
make docs-validate
```

### Documentation Standards

- **Clear and Concise**: Use simple, clear language
- **Examples**: Include practical examples
- **Formatting**: Use consistent markdown formatting
- **Links**: Link to relevant external documentation
- **Updates**: Keep documentation up to date with code changes

## 🔍 Pull Request Process

### Before Submitting

1. **✅ Self-Review Checklist**
   ```bash
   # Run all checks
   make pre-commit-all
   
   # Verify tests pass
   make test
   
   # Check documentation
   make docs-validate
   
   # Security scan
   make security-scan
   ```

2. **📝 PR Description Template**
   ```markdown
   ## Description
   Brief description of changes
   
   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update
   
   ## Testing
   - [ ] Unit tests pass
   - [ ] Integration tests pass
   - [ ] Manual testing completed
   
   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Self-review completed
   - [ ] Documentation updated
   - [ ] Tests added/updated
   ```

### Review Process

1. **Automated Checks**: All CI checks must pass
2. **Peer Review**: At least one maintainer review required
3. **Security Review**: Security-sensitive changes require security team review
4. **Documentation Review**: Documentation changes reviewed for clarity

### Merge Requirements

- ✅ All CI checks passing
- ✅ At least one approved review
- ✅ No merge conflicts
- ✅ Up-to-date with base branch
- ✅ Security scan passed

## 🐛 Issue Guidelines

### Bug Reports

Use the bug report template:

```markdown
**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Environment:**
- OS: [e.g., macOS, Ubuntu]
- Terraform version: [e.g., 1.6.0]
- Cloud provider: [e.g., DigitalOcean, Azure, AWS]
- Module version: [e.g., 2.1.0]

**Additional context**
Add any other context about the problem here.
```

### Feature Requests

Use the feature request template:

```markdown
**Is your feature request related to a problem?**
A clear and concise description of what the problem is.

**Describe the solution you'd like**
A clear and concise description of what you want to happen.

**Describe alternatives you've considered**
A clear and concise description of any alternative solutions.

**Additional context**
Add any other context or screenshots about the feature request here.
```

### Issue Labels

We use the following labels:

- **Type**: `bug`, `feature`, `documentation`, `question`
- **Priority**: `low`, `medium`, `high`, `critical`
- **Status**: `needs-triage`, `in-progress`, `waiting-for-response`
- **Cloud**: `digitalocean`, `azure`, `aws`, `multi-cloud`

## 🏆 Recognition

We recognize contributors in the following ways:

- **Contributors List**: Listed in README.md
- **Release Notes**: Mentioned in release notes
- **Hall of Fame**: Special recognition for significant contributions
- **Swag**: Stickers and swag for active contributors

## 📞 Community

### Communication Channels

- **GitHub Discussions**: For general questions and discussions
- **Issues**: For bug reports and feature requests
- **Slack**: Join our [Slack workspace](https://join.slack.com/your-workspace)
- **Office Hours**: Monthly community office hours

### Getting Help

- **Documentation**: Check our comprehensive docs
- **Stack Overflow**: Tag questions with `terraform-multicloud-kubernetes`
- **GitHub Discussions**: Ask questions in discussions
- **Community Chat**: Join our Slack for real-time help

### Maintainers

Current maintainers:

- **@animesh-mukherjee-devops** - Project Lead
- **@maintainer2** - Cloud Infrastructure Specialist
- **@maintainer3** - Security & Compliance Lead

---

Thank you for contributing to making multi-cloud Kubernetes infrastructure more accessible and secure! 🚀