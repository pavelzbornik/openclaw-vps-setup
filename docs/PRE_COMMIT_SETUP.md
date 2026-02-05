# Pre-commit Setup Guide

This repository uses [pre-commit](https://pre-commit.com/) to run automated checks before commits are made. This ensures code quality and consistency across the project.

## Quick Start

### 1. Install pre-commit

```bash
# Using pip
pip install pre-commit

# Using brew (macOS)
brew install pre-commit

# Using apt (Ubuntu/Debian)
sudo apt-get install pre-commit
```

### 2. Install the git hook scripts

```bash
cd /workspaces/openclaw
pre-commit install
```

### 3. (Optional) Run against all files

```bash
pre-commit run --all-files
```

## What Gets Checked

The pre-commit hooks run the following checks:

### General Checks
- **Large files**: Prevents commits of files over 1MB
- **Merge conflicts**: Detects unresolved merge conflict markers
- **File formatting**: Fixes trailing whitespace and ensures files end with newline
- **Line endings**: Normalizes to LF line endings
- **YAML/JSON syntax**: Validates YAML and JSON files
- **Executables**: Checks that scripts have proper shebangs

### Shell Scripts
- **ShellCheck**: Lints shell scripts for common errors and bad practices

### Terraform
- **terraform fmt**: Auto-formats Terraform files
- **terraform validate**: Validates Terraform configuration
- **terraform docs**: Auto-generates documentation
- **tflint**: Additional Terraform linting
- **trivy**: Security scanning for Terraform

### Ansible
- **ansible-lint**: Lints Ansible playbooks and roles using production profile
- **yamllint**: General YAML linting

### Markdown
- **markdownlint**: Lints and auto-fixes Markdown files

### Security
- **detect-secrets**: Scans for accidentally committed secrets
- **detect-private-key**: Prevents committing private keys

## Usage

Once installed, pre-commit hooks run automatically on `git commit`. If any checks fail, the commit will be blocked and you'll need to fix the issues.

### Manual execution

```bash
# Run all hooks on staged files
pre-commit run

# Run all hooks on all files
pre-commit run --all-files

# Run a specific hook
pre-commit run shellcheck --all-files
pre-commit run terraform-fmt --all-files
```

### Skipping hooks (use sparingly!)

```bash
# Skip all hooks for a commit (not recommended)
git commit --no-verify

# Skip specific hooks using SKIP environment variable
SKIP=shellcheck git commit -m "message"
```

## Updating Hooks

Pre-commit hook versions are pinned in `.pre-commit-config.yaml`. To update:

```bash
# Update to the latest versions
pre-commit autoupdate

# Update specific hook
pre-commit autoupdate --repo https://github.com/pre-commit/pre-commit-hooks
```

## Troubleshooting

### Hooks fail on first run
Some hooks may fail the first time because they auto-fix issues. Simply stage the fixes and commit again:

```bash
git add -u
git commit
```

### terraform_validate fails
Make sure you've run `terraform init` in each Terraform directory first:

```bash
cd terraform/discord
terraform init
```

### ansible-lint fails
Review the ansible-lint output. You may need to:
- Fix syntax errors in YAML files
- Add proper tags to tasks
- Follow Ansible best practices

### False positives in detect-secrets
If detect-secrets flags something that isn't actually a secret, you can update the baseline:

```bash
detect-secrets scan --baseline .secrets.baseline
```

## CI/CD Integration

Pre-commit can also run in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run pre-commit
  uses: pre-commit/action@v3.0.0
```

## Contributing

When contributing to this repository:
1. Install pre-commit before making your first commit
2. Ensure all hooks pass before pushing
3. Don't commit with `--no-verify` unless absolutely necessary
4. If you need to modify hook configuration, discuss it with the team first

## Additional Resources

- [Pre-commit documentation](https://pre-commit.com/)
- [Available pre-commit hooks](https://pre-commit.com/hooks.html)
- [ShellCheck wiki](https://github.com/koalaman/shellcheck/wiki)
- [Ansible Lint documentation](https://ansible-lint.readthedocs.io/)
- [Terraform docs](https://terraform-docs.io/)
