# Complete Setup Guide - From Scratch Deployment

## Important Notice

**This guide documents from-scratch deployment of the terraform-aws-oidc module for educational purposes only.**

This setup is designed to help you understand the complete architecture and implementation details by deploying all components from the ground up. **For production usage patterns and real-world implementation at scale, refer to [Real-World Usage at Appvia](./07-appvia-usage.md).**

**Key Distinctions:**
- **This guide**: From-scratch deployment to understand the complete system
- **Appvia Usage (07-appvia-usage.md)**: Production patterns solving the chicken-and-egg problems

**Target Environment:** Personal AWS test account only. Do not use in production or shared environments.

## Architecture Overview

This deployment creates a complete OIDC integration system:

```
GitHub Repository → OIDC Token → AWS IAM Role → Deploy Infrastructure
                                    ↓
                              S3 State Bucket
```

**Components deployed:**
1. OIDC Identity Providers (GitHub/GitLab)
2. IAM Roles with trust relationships
3. CI/CD workflows for automated deployment
4. State management infrastructure

## Prerequisites

Verify all requirements from [Hidden Dependencies](./02-hidden-dependencies.md) are met.

**Required tools verification:**
```bash
terraform --version    # >= 1.0.0
aws --version         # AWS CLI v2
curl --version        # For connectivity tests
jq --version         # For JSON processing
```

**AWS environment setup:**
```bash
aws sts get-caller-identity
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_DEFAULT_REGION=$(aws configure get region)
```

## Phase 1: S3 State Bucket Creation

The terraform-aws-oidc module requires pre-existing S3 bucket for state storage.

```bash
# Create Terraform state bucket
aws s3 mb s3://${AWS_ACCOUNT_ID}-${AWS_DEFAULT_REGION}-tfstate

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ${AWS_ACCOUNT_ID}-${AWS_DEFAULT_REGION}-tfstate \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ${AWS_ACCOUNT_ID}-${AWS_DEFAULT_REGION}-tfstate \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket ${AWS_ACCOUNT_ID}-${AWS_DEFAULT_REGION}-tfstate \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Verify creation
aws s3 ls s3://${AWS_ACCOUNT_ID}-${AWS_DEFAULT_REGION}-tfstate
```

## Phase 2: OIDC Provider Deployment

Deploy OIDC identity providers for GitHub and GitLab.

```bash
git clone https://github.com/appvia/terraform-aws-oidc.git
cd terraform-aws-oidc/examples/provider/

terraform init
terraform plan
terraform apply

# Verify deployment
aws iam list-open-id-connect-providers
```

**Expected resources created:**
- GitHub OIDC provider (token.actions.githubusercontent.com)
- GitLab OIDC provider (gitlab.com)
- Certificate thumbprint data

## Phase 3: IAM Roles Deployment

Create IAM roles with OIDC trust relationships.

**Critical Security Notice:** The provided role example contains dangerous configurations. Replace all policies before deployment.

### Secure Configuration

Create `terraform.tfvars` with restrictive policies:

```bash
cd ../role/

cat > terraform.tfvars << 'EOF'
repository = "your-github-org/your-test-repository"
name = "your-test-repository"
common_provider = "github"

# Restrictive permission boundary
permission_boundary_arn = "arn:aws:iam::aws:policy/PowerUserAccess"

# Limited read-only access
read_only_policy_arns = [
  "arn:aws:iam::aws:policy/ReadOnlyAccess"
]

# Specific service access only
read_write_policy_arns = [
  "arn:aws:iam::aws:policy/AmazonS3FullAccess",
  "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
]

# Branch protection
protected_by = {
  branch      = "main"
  environment = null
  tag         = null
}

tags = {
  Environment = "test"
  Purpose     = "oidc-integration-test"
}
EOF
```

### Replace placeholders with actual values:

```bash
sed -i "s/your-github-org/YOUR_ACTUAL_ORG/g" terraform.tfvars
sed -i "s/your-test-repository/YOUR_ACTUAL_REPO/g" terraform.tfvars
```

### Deploy roles:

```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# Verify role creation
aws iam list-roles --query 'Roles[?contains(RoleName, `your-test-repository`)]'
```

**Roles created:**
- `{name}-ro`: Read-only role for pull request validation
- `{name}`: Read-write role for main branch deployment
- `{name}-sr`: State reader role for cross-repository access

## Phase 4: CI/CD Workflow Configuration

Configure your application repository to use the created OIDC roles.

### Backend Configuration

In your application repository, create `terraform.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "ACCOUNT_ID-REGION-tfstate"
    key    = "REPOSITORY_NAME.tfstate"
    region = "REGION"
  }
}
```

### GitHub Actions Workflow

Create `.github/workflows/terraform.yml`:

```yaml
name: Terraform

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ vars.AWS_ACCOUNT_ID }}:role/REPOSITORY_NAME-ro
          aws-region: ${{ vars.AWS_DEFAULT_REGION }}
          
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        
      - name: Terraform Init
        run: terraform init
        
      - name: Terraform Plan
        run: terraform plan

  terraform-apply:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ vars.AWS_ACCOUNT_ID }}:role/REPOSITORY_NAME
          aws-region: ${{ vars.AWS_DEFAULT_REGION }}
          
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        
      - name: Terraform Init
        run: terraform init
        
      - name: Terraform Apply
        run: terraform apply -auto-approve
```

### Repository Variables

Configure in GitHub repository settings:
- `AWS_ACCOUNT_ID`: Your AWS account ID
- `AWS_DEFAULT_REGION`: Your AWS region

## Phase 5: Integration Testing

Test the complete OIDC workflow with a minimal resource.

### Test Resource

Create `test.tf` in your application repository:

```hcl
resource "aws_s3_bucket" "test" {
  bucket = "${random_id.test.hex}-oidc-test"
  
  tags = {
    Purpose = "oidc-integration-test"
  }
}

resource "random_id" "test" {
  byte_length = 4
}

output "test_bucket" {
  value = aws_s3_bucket.test.bucket
}
```

### Test Workflow

1. **Pull Request Test:**
   ```bash
   git checkout -b test/oidc
   git add test.tf
   git commit -m "test: OIDC integration"
   git push origin test/oidc
   ```
   Create PR → Workflow should run `terraform plan` with read-only role

2. **Main Branch Test:**
   ```bash
   git checkout main
   git merge test/oidc
   git push origin main
   ```
   Push to main → Workflow should run `terraform apply` with read-write role

### Verification

```bash
# Check bucket creation
aws s3 ls | grep oidc-test

# Verify state storage
aws s3 ls s3://${AWS_ACCOUNT_ID}-${AWS_DEFAULT_REGION}-tfstate/

# Check workflow logs for OIDC token exchange
```

## Success Criteria

**Deployment successful if:**
- ✅ Pull requests trigger terraform plan with read-only role
- ✅ Main branch pushes trigger terraform apply with read-write role
- ✅ State files stored in S3 bucket correctly
- ✅ No AWS access keys stored in GitHub secrets
- ✅ Test resources deploy and destroy correctly

**Common failure indicators:**
- ❌ "Token request failed" - Missing `id-token: write` permission
- ❌ "Role cannot be assumed" - Repository name mismatch in trust policy
- ❌ "S3 access denied" - Backend configuration incorrect
- ❌ "OIDC provider not found" - Provider deployment failed

## Cleanup

Remove test resources and optionally the entire setup:

```bash
# Remove test resources
rm test.tf
git add -A && git commit -m "cleanup: remove test resources"
git push origin main

# Optional: Destroy OIDC setup
cd terraform-aws-oidc/examples/role/
terraform destroy -var-file=terraform.tfvars

cd ../provider/
terraform destroy

# Remove S3 bucket (after emptying)
aws s3 rm s3://${AWS_ACCOUNT_ID}-${AWS_DEFAULT_REGION}-tfstate --recursive
aws s3 rb s3://${AWS_ACCOUNT_ID}-${AWS_DEFAULT_REGION}-tfstate
```

## Understanding vs Production Usage

**This guide provided:**
- Complete from-scratch understanding of all components
- Educational deployment in isolated test environment
- Foundation knowledge for production implementation

**For production usage:**
- Review [Real-World Usage at Appvia](./07-appvia-usage.md) for enterprise patterns
- Implement centralized role management
- Use shared workflow libraries
- Apply proper security boundaries and monitoring

## Next Steps

- **[Examples Analysis](./04-examples-analysis.md)** - Understand provided examples and security issues
- **[Security Best Practices](./05-security-best-practices.md)** - Production hardening guidelines  
- **[Real-World Usage at Appvia](./07-appvia-usage.md)** - Production implementation patterns
- **[Troubleshooting Guide](./06-troubleshooting-guide.md)** - Common issues and solutions