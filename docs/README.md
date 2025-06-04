# Terraform AWS OIDC Integration - Complete Documentation

This documentation provides comprehensive guidance for understanding, implementing, and troubleshooting the Terraform AWS OIDC Integration module. It covers all hidden dependencies, security considerations, and step-by-step implementation guides.

## 📚 Documentation Structure
- **[Architecture Overview](./01-architecture-overview.md)** - System architecture, data flows, and component interactions
- **[Hidden Dependencies](./02-hidden-dependencies.md)** - Critical prerequisites, assumptions, and undocumented requirements  
- **[Setup Guide](./03-setup-guide.md)** - Step-by-step implementation instructions
- **[Examples Analysis](./04-examples-analysis.md)** - Detailed analysis of provided examples with security considerations
- **[Security Best Practices](./05-security-best-practices.md)** - Security configurations and hardening guidelines
- **[Troubleshooting Guide](./06-troubleshooting-guide.md)** - Common issues and comprehensive solutions
- **[Real-World Usage at Appvia](./07-appvia-usage.md)** - Production usage patterns and enterprise-scale implementation


## 🚨 Important Security Notice

The provided examples in this repository contain **dangerous security configurations** including:
- `AdministratorAccess` policies attached to CI/CD roles
- Improper permission boundary usage
- Overly permissive trust policies

**Never use the example configurations in production without significant security hardening.**

## ⚠️ Testing and Development Notice

> **IMPORTANT NOTE**: All imperative commands shown in this documentation are intended for testing, development, and exploration purposes only in an AWS sandbox/test account. For production deployments, you should use a GitOps workflow to manage infrastructure changes and ensure that all behavior is tested beforehand and works as expected before upgrading to production.