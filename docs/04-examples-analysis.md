# Examples Analysis and Best Practices

This document provides detailed analysis of the provided examples, explaining their purpose, implementation, and how to use them safely in different environments.

## 📁 Examples Overview

The repository contains 4 example configurations that demonstrate different aspects of the OIDC integration:

```
examples/
├── provider/        # OIDC Provider creation (✅ Safe to use as-is)
├── role/           # IAM Role creation (⚠️ DANGEROUS - requires modification)
├── remote_state/   # Remote state reading (✅ Safe to use as-is)  
└── test-bitbucket/ # Bitbucket testing (❌ Broken - do not use)
```

## Example-by-Example Analysis

### 1. Provider Example (`examples/provider/`)

**Purpose**: Demonstrates how to create OIDC identity providers for GitHub and GitLab.

**What it does**:
- Creates GitHub OIDC provider (`https://token.actions.githubusercontent.com`)
- Creates GitLab OIDC provider (`https://gitlab.com`)
- Shows both common providers and custom provider configuration
- Demonstrates per-provider tagging

**Security Assessment**: ✅ **Safe to use as-is**

**Key Learning Points**:
```hcl
# Common providers - predefined configurations
common_providers = ["github", "gitlab"]

# Custom providers - full control over configuration
custom_providers = {
  gitlab = {
    name = "GitLab"
    url = "https://gitlab.example.org"
    client_id_list = ["https://gitlab.example.org"]
    thumbprint_list = ["92bed42098f508e91f47f321f6607e4b"]
  }
}
```

**When to Use**: Start here for any OIDC setup. Deploy this first before creating roles.

### 2. Role Example (`examples/role/`) 

**Purpose**: Demonstrates creating IAM roles with OIDC trust relationships.

⚠️ **CRITICAL SECURITY ISSUE**: This example uses `AdministratorAccess` for both policies AND permission boundaries. Since permission boundaries are meant to restrict permissions, using `AdministratorAccess` as a boundary provides NO security protection whatsoever.

**Dangerous Configurations**:
```hcl
# DANGEROUS - Permission boundary provides no protection
permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

# DANGEROUS - Full admin access to CI/CD pipelines  
read_write_policy_arns = [
  "arn:aws:iam::aws:policy/AdministratorAccess",
]
```

**Safe Usage Pattern**:
```hcl
# Use restrictive permission boundary
permission_boundary_arn = "arn:aws:iam::aws:policy/PowerUserAccess"

# Grant specific service permissions only
read_write_policy_arns = [
  "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
  "arn:aws:iam::aws:policy/AmazonS3FullAccess"
]

# Restrict to specific branches/environments
protected_by = {
  branch = "main"
  environment = null
  tag = null
}
```

**When to Use**: **Never use as-is in production**. Use as template but replace all policies with restrictive ones.

### 3. Remote State Example (`examples/remote_state/`)

**Purpose**: Demonstrates reading Terraform state from other repositories using OIDC authentication.

**What it does**:
- Shows cross-account state reading
- Demonstrates web identity token usage
- Configures S3 backend with role assumption

**Security Assessment**: ✅ **Safe to use as-is**

**Key Learning Points**:
```hcl
# Cross-account state reading
account_id = "0123456789"  # Target account
repository = "appvia/repo-1"  # Repository that created the state

# OIDC authentication
web_identity_token_file = "/tmp/web_identity_token_file"
```

**When to Use**: When you need to read infrastructure outputs from other repositories (e.g., VPC ID from shared infrastructure repo).

**Common Use Case Scenario**:
- **Repository A** (`shared-infrastructure`): Creates VPC, subnets, and outputs their IDs
- **Repository B** (`application`): Needs VPC/subnet IDs to deploy applications
- **Solution**: Repository B uses the `remote_state` module to read Repository A's Terraform outputs
- **Benefit**: Teams can share infrastructure without giving direct AWS permissions

### 4. Test Bitbucket Example (`examples/test-bitbucket/`)

**Purpose**: Intended to demonstrate Bitbucket Pipelines integration.

**Current State**: ❌ **Completely Broken**
- Contains copy-pasted provider example code (wrong module)
- No Bitbucket-specific OIDC configuration
- Missing required UUID configurations
- No `bitbucket-pipelines.yml` examples
- Does not demonstrate Bitbucket OIDC integration at all

**Missing Components**:
- Workspace UUID configuration
- Repository UUID setup
- Bitbucket-specific trust policies
- Pipeline YAML examples

**Recommendation**: **Do not use**. Create your own Bitbucket configuration following the main documentation instead of relying on this broken example.

## Examples Usage Workflow

### For Learning/Testing:
1. **Start with `provider/`** - Deploy OIDC providers first
2. **Modify `role/`** - Replace dangerous policies with safe ones
3. **Test with `remote_state/`** - Practice cross-repository access
4. **Skip `test-bitbucket/`** - Use dedicated Bitbucket documentation instead

### For Production:
1. **Provider example (`provider/`)**: Safe to use without modification
2. **Role example (`role/`)**: NEVER use as-is - replace ALL policies and boundaries with restrictive ones
3. **Remote state example (`remote_state/`)**: Safe to use but verify state reader roles exist
4. **Bitbucket example (`test-bitbucket/`)**: Ignore completely - create from scratch using docs

## Common Misunderstandings

### 1. "Permission Boundary = Security"
**Wrong**: `AdministratorAccess` boundary provides zero protection
```hcl
# This does nothing for security
permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
```

**Right**: Use restrictive boundaries
```hcl
# This actually limits permissions
permission_boundary_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
```

### 2. "Examples are Production-Ready"
**Wrong**: Examples are ready to deploy to production
**Right**: Examples are simplified for learning and require significant security hardening before production use

### 3. "All Three Roles Have Same Permissions"
**Wrong**: The three roles are interchangeable
**Right**: Each role has distinct permissions and use cases:
- `{name}-ro`: Read-only role for pull request validation (terraform plan)
- `{name}`: Read-write role for deployments (terraform apply)
- `{name}-sr`: State reader role for cross-repository state sharing

## Testing Examples Safely

### 1. Use Dedicated Test Account
```bash
# Never test in production account
aws configure --profile test-account
export AWS_PROFILE=test-account
```

### 2. Create Test Permission Boundary
```bash
aws iam create-policy \
  --policy-name TestBoundary \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["s3:*", "ec2:Describe*"],
        "Resource": "*"
      }
    ]
  }'
```

### 3. Replace Dangerous Configurations
```hcl
# Replace in terraform.tfvars
permission_boundary_arn = "arn:aws:iam::ACCOUNT:policy/TestBoundary"
read_write_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
```

## Development and Validation Tools

The repository includes comprehensive validation via Makefile:

### Available Commands
```bash
make all           # Complete validation pipeline
make validate      # Terraform validation
make lint         # TFLint validation  
make security     # Trivy security scan
make tests        # Terraform tests
make format       # Code formatting
make documentation # Generate docs
```

### Recommended Development Workflow
```bash
# 1. Install required tools
brew install terraform terraform-docs tflint trivy

# 2. Run validation before changes
make validate

# 3. Make changes to examples

# 4. Run complete validation
make all

# 5. Commit only if all validations pass
```

### Security Scanning Results
The `make security` command will flag the dangerous configurations in the role example:
- High-severity findings for `AdministratorAccess` usage
- Warnings about overly permissive policies
- Recommendations for principle of least privilege

## Summary

| Example | Production Safety | Purpose | Action Required |
|---------|------------------|---------|----------------|
| `provider/` | ✅ **SAFE** | Create OIDC providers | Deploy as-is |
| `role/` | ❌ **DANGEROUS** | Create IAM roles | Replace ALL policies before use |
| `remote_state/` | ✅ **SAFE** | Read remote state | Verify prerequisites then use |
| `test-bitbucket/` | ❌ **BROKEN** | Bitbucket integration | Do not use - create from scratch |

**Key Takeaway**: These examples are designed for learning the module's functionality, not for production deployment. The role example in particular demonstrates what NOT to do with security. Always apply the principle of least privilege and use restrictive permission boundaries before any production use.

## Next Steps

- **[Setup Guide](./03-setup-guide.md)** - Step-by-step secure implementation
- **[Security Best Practices](./05-security-best-practices.md)** - Production hardening guidelines
- **[Troubleshooting Guide](./06-troubleshooting-guide.md)** - Debug examples issues