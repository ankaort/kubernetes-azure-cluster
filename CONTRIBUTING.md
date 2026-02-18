# Contributing to Kubernetes Azure Cluster

Thank you for your interest in contributing! This document provides guidelines and information for contributors.

## Development Setup

### Prerequisites

1. Install required tools:
   ```bash
   # Azure CLI
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Terraform
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   
   # kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   ```

2. Authenticate with Azure:
   ```bash
   az login
   az account set --subscription "<your-subscription-id>"
   ```

## Code Standards

### Terraform

- Run `terraform fmt` before committing
- Run `terraform validate` to check syntax
- Follow HashiCorp's [Terraform Style Guide](https://www.terraform.io/docs/language/syntax/style.html)
- Use meaningful variable and resource names
- Add comments for complex logic
- Keep modules focused and reusable

### Shell Scripts

- Use `#!/bin/bash` shebang
- Enable strict mode: `set -e`
- Add comments for complex operations
- Use meaningful variable names (UPPER_CASE for constants)
- Check syntax with `bash -n script.sh`

### Kubernetes Manifests

- Use YAML format (not JSON)
- Validate with `kubectl apply --dry-run=client`
- Include resource limits and requests
- Add labels and annotations
- Use namespaces appropriately

## Testing

### Terraform

```bash
cd terraform
terraform init
terraform validate
terraform plan
```

### Scripts

```bash
# Syntax check
bash -n scripts/setup-control-plane.sh

# ShellCheck (if available)
shellcheck scripts/*.sh
```

### Kubernetes YAML

```bash
# Python YAML validation
python3 -c "import yaml; yaml.safe_load_all(open('kubernetes/mongodb-statefulset.yaml'))"

# kubectl validation (requires cluster)
kubectl apply --dry-run=client -f kubernetes/
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test your changes thoroughly
5. Commit with meaningful messages
6. Push to your fork
7. Create a Pull Request

### PR Guidelines

- Provide clear description of changes
- Reference related issues
- Include testing evidence
- Update documentation if needed
- Ensure all checks pass

## Reporting Issues

When reporting issues, include:

1. **Environment details**:
   - Azure region
   - Terraform version
   - Kubernetes version
   - OS version

2. **Steps to reproduce**:
   - Commands executed
   - Configuration used
   - Expected vs actual behavior

3. **Logs and outputs**:
   - Error messages
   - Terraform output
   - Kubernetes events
   - VM logs

## Feature Requests

We welcome feature requests! Please:

1. Check existing issues first
2. Provide clear use case
3. Explain expected behavior
4. Consider implementation complexity
5. Be patient - this is a community project

## Code Review Process

All submissions require review. We will:

1. Check code quality and standards
2. Verify testing
3. Review documentation
4. Test functionality
5. Provide constructive feedback

## Community

- Be respectful and professional
- Help others in discussions
- Share your experiences
- Contribute documentation improvements

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
