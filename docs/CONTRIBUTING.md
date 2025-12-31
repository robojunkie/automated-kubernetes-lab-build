# Contributing Guidelines

## How to Contribute

We welcome contributions from the community! Whether it's bug fixes, new features, or documentation improvements, we'd love your help.

## Getting Started

1. **Fork the repository**: Click the "Fork" button on GitHub
2. **Clone your fork**: `git clone https://github.com/YOUR_USERNAME/automated-kubernetes-lab-build.git`
3. **Create a branch**: `git checkout -b feature/your-feature-name`
4. **Make your changes**: Implement your feature or fix
5. **Test your changes**: Ensure they work as expected
6. **Commit your changes**: `git commit -m "Description of changes"`
7. **Push to your fork**: `git push origin feature/your-feature-name`
8. **Create a pull request**: Submit your PR on GitHub

## Code Style Guidelines

### Bash Scripts
- Use 4-space indentation
- Use meaningful variable names (no single letters except in loops)
- Add comments for complex logic
- Use local variables in functions
- Follow shellcheck recommendations

Example:
```bash
#!/bin/bash

# This is a well-structured function
my_function() {
    local input=$1
    local result=""
    
    # Process input
    result=$(echo "$input" | tr '[:lower:]' '[:upper:]')
    
    echo "$result"
}
```

### YAML Files
- Use 2-space indentation (standard for YAML)
- Use meaningful names for resources
- Add descriptions and labels
- Include examples

Example:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
  namespace: default
  labels:
    app: my-app
data:
  config: |
    key: value
```

### Documentation
- Use clear, concise language
- Include examples where appropriate
- Link to relevant documentation
- Keep lines to 80 characters for readability

## Commit Message Format

Use clear, descriptive commit messages:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, missing semicolons, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Build process, dependencies, etc.

Example:
```
feat(networking): add support for Calico BGP configuration

This commit adds support for configuring Calico with BGP mode
for improved network performance in production environments.

Resolves #123
```

## Testing

Before submitting a PR:

1. **Test in a lab environment**: Ensure the feature works as intended
2. **Test with different configurations**: Try different subnets, node counts, etc.
3. **Check for errors**: Run shellcheck on bash scripts
4. **Verify documentation**: Ensure docs are accurate

## Pull Request Process

1. **Title**: Use a clear, descriptive title
2. **Description**: Explain what the PR does and why
3. **Testing**: Describe how you tested the changes
4. **Breaking Changes**: Note any breaking changes
5. **Related Issues**: Reference related issues with `Fixes #123`

Example PR template:
```
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation

## Testing
How to test these changes:
1. Clone the branch
2. Run the script
3. Verify output

## Related Issues
Fixes #123
```

## Reporting Bugs

When reporting a bug:

1. **Title**: Brief description of the bug
2. **Reproduction steps**: Step-by-step instructions
3. **Expected behavior**: What should happen
4. **Actual behavior**: What actually happens
5. **Environment**: OS, Kubernetes version, config details
6. **Logs**: Relevant error messages or logs

Example bug report template:
```
## Bug Description
Brief description of the bug

## Steps to Reproduce
1. Run bash build-lab.sh
2. Enter configuration X
3. Wait for error

## Expected Behavior
Script should complete successfully

## Actual Behavior
Script fails with error message

## Environment
- OS: Ubuntu 20.04
- Kubernetes Version: 1.28
- Configuration: 2 workers, Calico CNI

## Logs
[Paste error logs here]
```

## Feature Requests

When requesting a feature:

1. **Title**: Brief description of the feature
2. **Use case**: Why do you need this feature?
3. **Proposed solution**: How should it work?
4. **Alternatives**: Other approaches you considered

## Development Setup

### Prerequisites
- Bash 4.0+
- SSH client
- kubectl (for testing)

### Local Testing
```bash
# Make script executable
chmod +x scripts/build-lab.sh

# Test with dry-run mode
bash scripts/build-lab.sh -d -c examples/example-config.env

# Check for bash errors
shellcheck scripts/**/*.sh
```

## Documentation

Good documentation is crucial. When adding features:

1. **Update README.md**: Add to features or quick start if applicable
2. **Create/update docs**: Add detailed documentation if needed
3. **Add examples**: Include YAML examples for new features
4. **Update comments**: Explain complex logic in code

## Area-Specific Guidelines

### Networking Module
- Test with multiple CNI plugins
- Verify LAN accessibility works
- Document new network-related features

### Kubernetes Deployment Module
- Test with different Kubernetes versions
- Verify node join process
- Test with various cluster sizes

### Add-ons Module
- Test addon installation and configuration
- Verify addon integration with base cluster
- Document addon-specific configuration

## Review Process

1. **Initial review**: Maintainers review for completeness and style
2. **Testing**: PR is tested in lab environments
3. **Feedback**: Comments or requests for changes
4. **Approval**: PR is approved and merged

## Community Standards

We are committed to providing a welcoming and inclusive community. Please be:

- **Respectful**: Treat others with respect
- **Professional**: Keep discussions focused and productive
- **Helpful**: Answer questions and share knowledge
- **Inclusive**: Welcome people of all backgrounds

See our Code of Conduct for more details.

## Questions?

If you have questions about contributing:

1. Check existing issues and discussions
2. Read the documentation
3. Ask in GitHub discussions
4. Open an issue with your question

## License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Automated Kubernetes Lab Build!
