# Troubleshooting Guide

This comprehensive troubleshooting guide addresses common issues encountered when implementing and using the Terraform AWS OIDC Integration module.

## 📋 Quick Issue Index

| Issue Category | Common Problems | Severity | Quick Fix |
|---------------|-----------------|----------|----------|
| **Authentication** | Token request failed, Access denied | 🔴 HIGH | Check permissions, trust policies |
| **Configuration** | Provider not found, Repository mismatch | 🔴 HIGH | Verify module deployment order |
| **Infrastructure** | S3 bucket missing, State locking | 🟠 MEDIUM | Create bucket, clear locks |
| **Network** | Certificate errors, Firewall blocks | 🟠 MEDIUM | Check connectivity, proxy settings |
| **Permissions** | Boundary violations, Policy denials | 🟠 MEDIUM | Review IAM policies, boundaries |
| **CI/CD Platform** | GitLab/Bitbucket setup issues | 🟡 LOW | Platform-specific configuration |

**🚨 Critical Path Issues** (resolve in this order):
1. **S3 state bucket missing** → Create bucket using AWS CLI
2. **OIDC provider not deployed** → Deploy provider module first
3. **Role trust policy mismatch** → Verify repository name matches exactly
4. **Missing id-token permission** → Add `id-token: write` to workflow

## 🔧 Quick Diagnostic Tools

### Environment Health Check Script

**Purpose**: This script performs a comprehensive health check of your OIDC integration setup, checking all critical dependencies and configurations.

**What it checks**:
- AWS credentials and access
- Required development tools
- S3 state bucket existence and configuration
- OIDC provider deployment status
- Network connectivity to OIDC endpoints

```bash
#!/bin/bash
# oidc-health-check.sh - Quick diagnostic script

echo "=== OIDC Module Health Check ==="
echo

# Check AWS credentials
echo "1. AWS Credentials Check:"
if aws sts get-caller-identity &>/dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    REGION=$(aws configure get region || echo "not-set")
    echo "✅ AWS access OK - Account: $ACCOUNT_ID, Region: $REGION"
else
    echo "❌ AWS credentials not configured or invalid"
    echo "   Run: aws configure"
    exit 1
fi

# Check required tools
echo -e "\n2. Required Tools Check:"
tools=("terraform" "terraform-docs" "tflint" "trivy" "git")
for tool in "${tools[@]}"; do
    if command -v $tool &>/dev/null; then
        version=$($tool --version 2>&1 | head -n1)
        echo "✅ $tool: installed"
    else
        echo "❌ $tool: Not installed"
    fi
done

# Check S3 state bucket
echo -e "\n3. S3 State Bucket Check:"
BUCKET_NAME="${ACCOUNT_ID}-${REGION}-tfstate"
if aws s3api head-bucket --bucket "$BUCKET_NAME" &>/dev/null; then
    echo "✅ S3 bucket exists: $BUCKET_NAME"
    
    # Check bucket versioning
    VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --query Status --output text)
    if [[ "$VERSIONING" == "Enabled" ]]; then
        echo "✅ Bucket versioning enabled"
    else
        echo "⚠️  Bucket versioning not enabled (recommended)"
    fi
else
    echo "❌ S3 bucket missing: $BUCKET_NAME"
fi

# Check OIDC providers
echo -e "\n4. OIDC Providers Check:"
PROVIDERS=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[*].Arn' --output text)
if [[ -n "$PROVIDERS" ]]; then
    echo "✅ OIDC providers found:"
    for provider in $PROVIDERS; do
        URL=$(aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$provider" --query Url --output text)
        echo "   - $URL"
    done
else
    echo "⚠️  No OIDC providers found - deploy provider module first"
fi

# Check network connectivity
echo -e "\n5. Network Connectivity Check:"
endpoints=("https://token.actions.githubusercontent.com" "https://gitlab.com")
for endpoint in "${endpoints[@]}"; do
    if curl -s --connect-timeout 5 "$endpoint/.well-known/openid_configuration" | jq -e .issuer &>/dev/null; then
        echo "✅ $endpoint: Accessible"
    else
        echo "❌ $endpoint: Not accessible"
    fi
done

echo -e "\n=== Health Check Complete ==="
```

### Make Script Executable and Run
```bash
chmod +x oidc-health-check.sh
./oidc-health-check.sh
```

## Common Issues and Solutions

### Critical Issues (Fix These First)

### 1. "Token request failed" in GitHub Actions

**Impact**: Complete deployment failure, no resources can be deployed
**Frequency**: Very common (affects 60% of first-time setups)

**Symptoms:**
```
Error: Could not retrieve the OIDC token.
RequestError: Error message: Could not get ID token.
Error: The security token included in the request is invalid
```

**Root Causes & Solutions:**

#### Missing Permissions Block
```yaml
# WRONG: Missing id-token permission
permissions:
  contents: read

# CORRECT: Include id-token permission
permissions:
  id-token: write    # CRITICAL: Required for OIDC
  contents: read
```

#### Repository Settings Issue
```bash
# Check repository settings
# Go to: Repository Settings > Actions > General
# Ensure "Read and write permissions" or specific permissions are enabled

# Verify workflow permissions
echo "Current repo permissions:"
gh api repos/OWNER/REPO --jq '.permissions'
```

#### Role ARN Configuration Issues
```yaml
# WRONG: Using secrets (which are masked in logs)
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}  # Hard to debug

# BETTER: Use variables for non-sensitive values
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::${{ vars.AWS_ACCOUNT_ID }}:role/${{ vars.ROLE_NAME }}
    aws-region: ${{ vars.AWS_DEFAULT_REGION }}
```

### 2. "No such identity provider" Error

**Impact**: Role assumption fails completely
**Root Cause**: Module deployment order issue - roles deployed before providers

**Symptoms:**
```
Error: InvalidIdentityToken: No OpenIDConnect provider found in your account for https://token.actions.githubusercontent.com
Error: Invalid provider configuration
Error reading IAM OIDC Provider: NoSuchEntity
```

**Diagnostic Commands:**
```bash
# Check if OIDC provider exists
aws iam list-open-id-connect-providers

# Check specific provider
# Replace ACCOUNT with your actual AWS account ID
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com \
  2>/dev/null || echo "Provider not found"

# Check provider URL format
curl -s https://token.actions.githubusercontent.com/.well-known/openid_configuration | jq .issuer
```

**Solutions:**

#### Deploy Provider Module First
```bash
cd examples/provider/
terraform init
terraform plan
terraform apply  # Creates OIDC providers
```

#### Check Provider Configuration
```hcl
# Verify provider module configuration
module "github_provider" {
  source = "../../modules/provider"
  
  common_providers = ["github"]  # Must match exactly
  
  tags = {
    Environment = "production"
  }
}
```

### 3. "Access Denied" When Assuming Role

**Impact**: Authentication works but authorization fails
**Root Cause**: Trust policy conditions don't match OIDC token claims

**Symptoms:**
```
Error: AccessDenied: User: arn:aws:sts::123456789012:assumed-role/... is not authorized to perform: sts:AssumeRoleWithWebIdentity
Error: Token audience validation failed
Error: Subject claim does not match expected pattern
```

**Diagnostic Process:**

#### Check Trust Policy
```bash
# Get role trust policy
aws iam get-role --role-name YOUR-ROLE-NAME --query 'Role.AssumeRolePolicyDocument'

# Decode and examine conditions
aws iam get-role --role-name YOUR-ROLE-NAME \
  --query 'Role.AssumeRolePolicyDocument' | \
  jq '.Statement[0].Condition'
```

#### Debug Token Claims
```yaml
# Add to GitHub Actions workflow for debugging
- name: Debug OIDC Token Claims
  run: |
    echo "Repository: ${{ github.repository }}"
    echo "Ref: ${{ github.ref }}"
    echo "Actor: ${{ github.actor }}"
    echo "Environment: ${{ github.environment }}"
    echo "Repository Owner: ${{ github.repository_owner }}"
```

#### Common Trust Policy Issues

**Issue: Subject Pattern Mismatch**
```hcl
# WRONG: Too restrictive (only allows main branch)
condition {
  test     = "StringEquals"  # Exact match required
  variable = "token.actions.githubusercontent.com:sub"
  values   = ["repo:myorg/myrepo:ref:refs/heads/main"]
}

# BETTER: Allow all contexts in the repository
condition {
  test     = "StringLike"    # Pattern matching with wildcard
  variable = "token.actions.githubusercontent.com:sub"
  values   = ["repo:myorg/myrepo:*"]  # Allows PRs, branches, tags
}
```

**Issue: Audience Mismatch**
```hcl
# WRONG: Incorrect audience for GitHub
condition {
  test     = "StringEquals"
  variable = "token.actions.githubusercontent.com:aud"
  values   = ["https://github.com"]  # Wrong!
}

# CORRECT: GitHub uses this audience
condition {
  test     = "StringEquals"
  variable = "token.actions.githubusercontent.com:aud"
  values   = ["sts.amazonaws.com"]   # Correct!
}
```

### 4. "S3 bucket does not exist" Error

**Impact**: Terraform backend initialization fails
**Root Cause**: Missing prerequisite - S3 bucket must be created manually before deploying OIDC module

**Symptoms:**
```
Error: S3 bucket does not exist: 123456789012-us-east-1-tfstate
Error: Failed to configure Terraform backend
Error: The specified bucket does not exist
```

**Why this happens**: The OIDC module creates roles that can access the S3 bucket, but doesn't create the bucket itself. This is a common "chicken and egg" problem in infrastructure setup.

**Solution:**
```bash
# Create the required S3 bucket with error handling
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REGION=$(aws configure get region || echo "us-east-1")

# Check if bucket already exists
if aws s3 ls s3://${ACCOUNT_ID}-${REGION}-tfstate 2>/dev/null; then
    echo "Bucket already exists"
else
    echo "Creating bucket: ${ACCOUNT_ID}-${REGION}-tfstate"
    aws s3 mb s3://${ACCOUNT_ID}-${REGION}-tfstate
fi

# Configure bucket security (required for production)
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket ${ACCOUNT_ID}-${REGION}-tfstate \
  --versioning-configuration Status=Enabled

echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket ${ACCOUNT_ID}-${REGION}-tfstate \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### 5. Certificate Thumbprint Issues

**Symptoms:**
```
Error: TLS certificate validation failed
InvalidThumbprint: Invalid thumbprint
```

**Diagnostic Commands:**
```bash
# Test certificate access
openssl s_client -connect token.actions.githubusercontent.com:443 \
  -servername token.actions.githubusercontent.com </dev/null

# Get current thumbprint
echo | openssl s_client -servername token.actions.githubusercontent.com \
  -connect token.actions.githubusercontent.com:443 2>/dev/null | \
  openssl x509 -fingerprint -noout -sha1 | \
  cut -d'=' -f2 | tr -d ':'
```

**Solutions:**

#### Manual Thumbprint Configuration
```hcl
module "custom_provider" {
  source = "./modules/provider"
  
  custom_providers = {
    github = {
      name = "GitHub"
      url  = "https://token.actions.githubusercontent.com"
      client_id_list = ["sts.amazonaws.com"]
      
      # Disable automatic lookup
      lookup_thumbprint = false
      
      # Provide manual thumbprint
      thumbprint_list = ["1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
    }
  }
}
```

#### Corporate Firewall Issues
```bash
# Test from different network
curl -v https://token.actions.githubusercontent.com/.well-known/openid_configuration

# Check proxy settings
echo $HTTP_PROXY
echo $HTTPS_PROXY

# Configure git/terraform to use proxy if needed
git config --global http.proxy http://proxy.company.com:8080
```

### 6. Permission Boundary Violations

**Symptoms:**
```
Error: AccessDenied: User is not authorized to perform: ec2:RunInstances
(Request was denied by an explicit deny in an identity-based policy)
```

**Diagnostic Process:**

#### Check Effective Permissions
```bash
# Simulate permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/ROLE-NAME \
  --action-names ec2:RunInstances \
  --resource-arns "*" \
  --context-entries ContextKeyName=aws:RequestedRegion,ContextKeyValues=us-east-1,ContextKeyType=string

# Check permission boundary
aws iam get-role --role-name ROLE-NAME \
  --query 'Role.PermissionsBoundary.PermissionsBoundaryArn'
```

#### Review Permission Boundary Policy
```bash
# Get boundary policy content
BOUNDARY_ARN=$(aws iam get-role --role-name ROLE-NAME --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' --output text)

aws iam get-policy --policy-arn "$BOUNDARY_ARN" \
  --query 'Policy.Arn'

aws iam get-policy-version \
  --policy-arn "$BOUNDARY_ARN" \
  --version-id v1 \
  --query 'PolicyVersion.Document'
```

**Solution:**
```hcl
# Create appropriate permission boundary
resource "aws_iam_policy" "correct_boundary" {
  name = "TerraformDeploymentBoundary"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "s3:*",
          "rds:*"
          # Add required actions
        ]
        Resource = "*"
      },
      {
        Effect = "Deny"
        Action = [
          "iam:*"  # Prevent privilege escalation
        ]
        Resource = "*"
      }
    ]
  })
}
```

### 7. State Locking Issues

**Symptoms:**
```
Error: Error locking state: Error acquiring the state lock
Lock ID: abc123-def456-ghi789
```

**Diagnostic Commands:**
```bash
# Check for existing locks
aws s3 ls s3://${ACCOUNT_ID}-${REGION}-tfstate/ | grep "\.tflock"

# View lock file content
aws s3 cp s3://${ACCOUNT_ID}-${REGION}-tfstate/REPO-NAME.tfstate.tflock - | jq .
```

**Solutions:**

#### Force Unlock (Use Carefully)
```bash
# WARNING: Only use if you're absolutely sure no other process is running
# Option 1: Use Terraform's force-unlock (safer)
terraform force-unlock LOCK-ID

# Option 2: Remove lock file directly (last resort)
# DANGER: Can cause state corruption if another process is running
aws s3 rm s3://${ACCOUNT_ID}-${REGION}-tfstate/REPO-NAME.tfstate.tflock
```

#### Implement DynamoDB Locking
```hcl
# Better locking with DynamoDB
terraform {
  backend "s3" {
    bucket         = "ACCOUNT-REGION-tfstate"
    key            = "REPO-NAME.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# Create DynamoDB table
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
}
```

### 8. GitLab CI Issues

**Impact**: GitLab pipelines cannot authenticate with AWS
**Common Causes**: Missing OIDC configuration, incorrect audience, project path mismatch

**Symptoms:**
```
Error: Could not retrieve OIDC token from GitLab
Error: OIDC token validation failed
Error: Project path does not match expected pattern
```

**Solutions:**

#### Check GitLab CI Configuration
```yaml
# Correct GitLab CI configuration
variables:
  AWS_DEFAULT_REGION: us-east-1
  # CRITICAL: These must match your actual AWS account and role names
  AWS_ACCOUNT_ID: "123456789012"  # Your AWS account ID
  AWS_ROLE_NAME: "my-project-name"  # Your role name from OIDC module

id_tokens:
  GITLAB_OIDC_TOKEN:
    aud: https://gitlab.com  # Must match provider audience exactly

before_script:
  - export AWS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AWS_ROLE_NAME}"
  - export AWS_WEB_IDENTITY_TOKEN_FILE=/tmp/web-identity-token
  - echo $GITLAB_OIDC_TOKEN > $AWS_WEB_IDENTITY_TOKEN_FILE
  # Debug: Check token file and contents
  - test -f $AWS_WEB_IDENTITY_TOKEN_FILE || { echo "ERROR: Token file not created"; exit 1; }
  - echo "Token file size: $(wc -c < $AWS_WEB_IDENTITY_TOKEN_FILE) bytes"
```

#### Debug GitLab Token and Configuration
```yaml
# Enhanced debugging for GitLab CI
script:
  - echo "=== GitLab CI OIDC Debug Information ==="
  - echo "GitLab OIDC Token present:" $([ -n "$GITLAB_OIDC_TOKEN" ] && echo "YES" || echo "NO")
  - echo "Token file exists:" $([ -f "/tmp/web-identity-token" ] && echo "YES" || echo "NO")
  - echo "Project Path: $CI_PROJECT_PATH"
  - echo "Ref Type: $CI_COMMIT_REF_SLUG"
  - echo "Ref Name: $CI_COMMIT_REF_NAME"
  - echo "Pipeline Source: $CI_PIPELINE_SOURCE"
  - echo "AWS Role ARN: $AWS_ROLE_ARN"
  # Decode token claims (for debugging only)
  - echo $GITLAB_OIDC_TOKEN | cut -d'.' -f2 | base64 -d | jq . || echo "Token decode failed"
```

#### GitLab-Specific Trust Policy Issues
```hcl
# Common GitLab trust policy problems and fixes

# WRONG: Incorrect subject pattern for GitLab
condition {
  test     = "StringLike"
  variable = "gitlab.com:sub"
  values   = ["repo:mygroup/myproject:*"]  # This is GitHub format!
}

# CORRECT: GitLab uses project_path format
condition {
  test     = "StringLike"
  variable = "gitlab.com:sub"
  values   = ["project_path:mygroup/myproject:*"]
}

# CORRECT: Branch-specific access for GitLab
condition {
  test     = "StringLike"
  variable = "gitlab.com:sub"
  values   = ["project_path:mygroup/myproject:ref_type:branch:ref:main"]
}
```

### 9. Bitbucket Pipelines Issues

**Impact**: Bitbucket pipelines cannot authenticate with AWS
**Common Causes**: Incorrect UUIDs, workspace configuration issues
**Note**: Bitbucket OIDC setup is more complex than GitHub/GitLab

**Symptoms:**
```
Error: Invalid repository UUID in OIDC token
Error: Workspace UUID not found
Error: OIDC endpoint not accessible
```

**Solutions:**

#### Step 1: Get Correct UUIDs (Critical)
```bash
# Method 1: Via Bitbucket Web Interface
# 1. Navigate to: Workspace settings > Security > OpenID Connect
# 2. Copy the workspace UUID (format: 12345678-1234-1234-1234-123456789012)
# 3. Navigate to: Repository settings > Security > OpenID Connect  
# 4. Copy the repository UUID (format: {87654321-4321-4321-4321-210987654321})
# Note: Repository UUID includes curly braces {}

# Method 2: Via Bitbucket API (requires authentication)
curl -X GET \
  "https://api.bitbucket.org/2.0/workspaces/YOUR-WORKSPACE" \
  -H "Authorization: Bearer YOUR-ACCESS-TOKEN" | jq .uuid

curl -X GET \
  "https://api.bitbucket.org/2.0/repositories/YOUR-WORKSPACE/YOUR-REPO" \
  -H "Authorization: Bearer YOUR-ACCESS-TOKEN" | jq .uuid
```

#### Step 2: Configure Bitbucket Provider Correctly
```hcl
# IMPORTANT: Bitbucket requires both workspace and repository UUIDs
module "bitbucket_provider" {
  source = "./modules/provider"
  
  # Method 1: Use workspace variables (recommended)
  workspace_name = "your-workspace-name"  # Without @ symbol
  workspace_uuid = "12345678-1234-1234-1234-123456789012"  # Lowercase, no brackets
  
  common_providers = ["bitbucket"]
  
  tags = {
    Environment = "production"
    Provider    = "bitbucket"
  }
}

# Method 2: Use custom provider configuration
module "bitbucket_custom_provider" {
  source = "./modules/provider"
  
  custom_providers = {
    bitbucket = {
      name = "Bitbucket"
      # Replace YOUR-WORKSPACE with actual workspace name
      url  = "https://api.bitbucket.org/2.0/workspaces/YOUR-WORKSPACE/pipelines-config/identity/oidc"
      client_id_list = [
        # Replace with actual workspace UUID (lowercase, no brackets)
        "ari:cloud:bitbucket::workspace/12345678-1234-1234-1234-123456789012"
      ]
    }
  }
}
```

#### Step 3: Configure Bitbucket Role with Repository UUID
```hcl
module "bitbucket_role" {
  source = "./modules/role"
  
  name        = "bitbucket-deployment"
  description = "Bitbucket OIDC deployment role"
  repository  = "your-workspace/your-repo"  # Standard format
  
  # CRITICAL: Bitbucket requires repository UUID
  repository_uuid = "{87654321-4321-4321-4321-210987654321}"
  workspace_name  = "your-workspace-name"
  workspace_uuid  = "12345678-1234-1234-1234-123456789012"
  
  common_provider = "bitbucket"
  
  # Protection settings
  protected_by = {
    branch = "main"  # Bitbucket uses simple branch names
  }
  
  tags = {
    Environment = "production"
    Platform    = "bitbucket"
  }
}
```

#### Step 4: Bitbucket Pipeline Configuration
```yaml
# bitbucket-pipelines.yml
image: atlassian/default-image:3

pipelines:
  branches:
    main:
      - step:
          name: Deploy to AWS
          oidc: true  # Enable OIDC
          script:
            # Debug OIDC token
            - echo "Bitbucket OIDC Token present:" $([ -n "$BITBUCKET_STEP_OIDC_TOKEN" ] && echo "YES" || echo "NO")
            - echo "Workspace: $BITBUCKET_WORKSPACE"
            - echo "Repository: $BITBUCKET_REPO_FULL_NAME"
            - echo "Repository UUID: $BITBUCKET_REPO_UUID"
            
            # Configure AWS credentials
            - export AWS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${AWS_ROLE_NAME}"
            - export AWS_WEB_IDENTITY_TOKEN_FILE=/tmp/web-identity-token
            - echo $BITBUCKET_STEP_OIDC_TOKEN > $AWS_WEB_IDENTITY_TOKEN_FILE
            
            # Install and configure AWS CLI
            - pip install awscli
            - aws sts get-caller-identity  # Verify authentication
            
            # Run Terraform
            - terraform init
            - terraform plan
            - terraform apply -auto-approve
```

### 10. Repository Name Mismatch

**Symptoms:**
```
Error: Subject does not match expected pattern
```

**Common Issues:**

#### Case Sensitivity
```hcl
# WRONG: Case mismatch (GitHub is case-sensitive)
repository = "MyOrg/MyRepo"  # GitHub actual: "myorg/myrepo"

# CORRECT: Use exact case from GitHub
repository = "myorg/myrepo"  # Must match github.repository context exactly
```

#### Repository Renamed
```bash
# Check current repository name
gh repo view --json name,owner

# Update module configuration
repository = "correct-org/correct-repo-name"
```

## Advanced Debugging Tools and Techniques

### Token Analysis and Validation

#### OIDC Token Inspection

```bash
# Decode OIDC token (in CI/CD environment)
# GitHub Actions
echo $ACTIONS_ID_TOKEN_REQUEST_TOKEN | base64 -d | jq .

# GitLab CI
echo $GITLAB_OIDC_TOKEN | cut -d'.' -f2 | base64 -d | jq .
```

### CloudTrail Analysis

```bash
# Search for OIDC-related events
aws logs filter-log-events \
  --log-group-name CloudTrail \
  --filter-pattern "AssumeRoleWithWebIdentity" \
  --start-time $(date -d '1 hour ago' +%s)000

# Search for specific errors
aws logs filter-log-events \
  --log-group-name CloudTrail \
  --filter-pattern "ERROR AssumeRoleWithWebIdentity" \
  --start-time $(date -d '1 day ago' +%s)000
```

### Advanced IAM Debugging

#### IAM Policy Simulator
```bash
# Test specific permissions with detailed output
ROLE_ARN="arn:aws:iam::ACCOUNT:role/ROLE-NAME"  # Replace with actual values

aws iam simulate-principal-policy \
  --policy-source-arn "$ROLE_ARN" \
  --action-names s3:GetObject,ec2:DescribeInstances \
  --resource-arns "*" \
  --output table

# Test with conditions and context
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/ROLE-NAME \
  --action-names ec2:RunInstances \
  --resource-arns "*" \
  --context-entries \
    ContextKeyName=ec2:InstanceType,ContextKeyValues=t3.micro,ContextKeyType=string \
    ContextKeyName=aws:RequestedRegion,ContextKeyValues=us-east-1,ContextKeyType=string

# Comprehensive permission test for Terraform operations
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/ROLE-NAME \
  --action-names \
    s3:GetObject,s3:PutObject,s3:ListBucket,s3:DeleteObject \
    ec2:DescribeInstances,ec2:RunInstances,ec2:TerminateInstances \
    iam:GetRole,iam:ListRoles \
  --resource-arns "*" \
  --output json | jq '.EvaluationResults[] | select(.EvalDecision != "allowed")'
```

#### Trust Relationship Deep Dive
```bash
# Comprehensive trust policy analysis
analyze_trust_policy() {
  local role_name="$1"
  
  echo "=== Trust Policy Analysis for $role_name ==="
  
  # Get trust policy
  aws iam get-role --role-name "$role_name" \
    --query 'Role.AssumeRolePolicyDocument' \
    --output json > trust_policy.json
  
  # Pretty print trust policy
  echo "Trust Policy:"
  jq . trust_policy.json
  
  # Extract conditions
  echo -e "\nConditions:"
  jq '.Statement[].Condition' trust_policy.json
  
  # Extract principals
  echo -e "\nPrincipals:"
  jq '.Statement[].Principal' trust_policy.json
  
  # Verify OIDC provider exists
  local provider_arn=$(jq -r '.Statement[].Principal.Federated[]' trust_policy.json)
  echo -e "\nOIDC Provider Status:"
  aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$provider_arn" \
    --query '{URL: Url, ClientIds: ClientIDList, Thumbprints: ThumbprintList}' \
    2>/dev/null || echo "❌ Provider not found: $provider_arn"
  
  rm -f trust_policy.json
}

# Usage: analyze_trust_policy "my-role-name"
```

## Prevention Strategies

### Pre-deployment Testing

```bash
# Test script for pre-deployment validation
#!/bin/bash
set -e

echo "Running pre-deployment tests..."

# Test 1: Validate Terraform syntax
terraform fmt -check
terraform validate

# Test 2: Run security scan
trivy config .

# Test 3: Test OIDC connectivity
curl -f https://token.actions.githubusercontent.com/.well-known/openid_configuration

# Test 4: Validate IAM policies
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/test-role \
  --action-names s3:GetObject \
  --resource-arns "*"

echo "All pre-deployment tests passed!"
```

### Monitoring Setup

```hcl
# CloudWatch dashboard for OIDC monitoring
resource "aws_cloudwatch_dashboard" "oidc_monitoring" {
  dashboard_name = "OIDC-Integration-Monitoring"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudTrail", "CallCount", "EventName", "AssumeRoleWithWebIdentity"]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "OIDC Role Assumptions"
        }
      }
    ]
  })
}
```

## Escalation Procedures

### When to Escalate

1. **Security-related issues** - Escalate immediately
2. **Production outages** - Follow incident response procedures  
3. **Persistent authentication failures** - Escalate after basic troubleshooting
4. **AWS service issues** - Check AWS Health Dashboard first

### Information to Collect

```bash
# Gather diagnostic information
#!/bin/bash
echo "=== OIDC Troubleshooting Information ==="
echo "Timestamp: $(date)"
echo "AWS Account: $(aws sts get-caller-identity --query Account --output text)"
echo "Region: $(aws configure get region)"
echo

echo "=== Error Details ==="
# Include specific error messages, stack traces, etc.

echo "=== Configuration ==="
terraform show -json | jq '.configuration'

echo "=== Recent CloudTrail Events ==="
aws logs filter-log-events \
  --log-group-name CloudTrail \
  --filter-pattern "AssumeRoleWithWebIdentity" \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --limit 10
```

## Emergency Procedures

### Break-Glass Access (Production Emergencies)

If OIDC authentication is completely broken in production:

```bash
# Emergency AWS access (requires pre-configured emergency procedures)
# ⚠️ Only use with explicit approval from security team

# 1. Switch to emergency IAM user profile
export AWS_PROFILE=emergency-user
aws sts get-caller-identity || echo "Emergency profile not configured"

# 2. Or assume emergency role with MFA
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT:role/emergency-admin \
  --role-session-name emergency-$(date +%s) \
  --serial-number arn:aws:iam::ACCOUNT:mfa/username \
  --token-code 123456

# 3. Fix OIDC issues systematically
echo "Step 1: Verify OIDC providers exist"
aws iam list-open-id-connect-providers

echo "Step 2: Check S3 bucket exists"
aws s3 ls s3://${ACCOUNT_ID}-${REGION}-tfstate

echo "Step 3: Verify role trust policies"
# Check each role's trust policy

# 4. Test recovery
echo "Running health check..."
./oidc-health-check.sh
```

### Rollback Procedures

```bash
# If recent changes broke OIDC integration
#!/bin/bash
set -e

echo "=== OIDC Module Rollback Procedure ==="

# 1. Identify last working state
echo "Checking Terraform state history..."
aws s3 ls s3://ACCOUNT-REGION-tfstate/ --recursive | grep terraform-aws-oidc

# 2. Backup current state
echo "Backing up current state..."
aws s3 cp s3://ACCOUNT-REGION-tfstate/terraform-aws-oidc.tfstate \
  ./backup-$(date +%Y%m%d-%H%M%S).tfstate

# 3. Restore previous working version
echo "Restoring previous state..."
# aws s3 cp ./previous-working.tfstate s3://ACCOUNT-REGION-tfstate/terraform-aws-oidc.tfstate

# 4. Re-run terraform to ensure consistency
echo "Applying restored configuration..."
terraform plan
terraform apply

# 5. Verify recovery
echo "Verifying OIDC functionality..."
./oidc-health-check.sh
```

## Troubleshooting Decision Tree

```
❌ OIDC Integration Not Working
    |
    ├─ 🔍 Can you access AWS CLI?
    │   ├─ NO → Check AWS credentials configuration
    │   └─ YES → Continue
    |
    ├─ 🔍 Does S3 state bucket exist?
    │   ├─ NO → Create S3 bucket first (see setup guide)
    │   └─ YES → Continue
    |
    ├─ 🔍 Are OIDC providers deployed?
    │   ├─ NO → Deploy provider module first
    │   └─ YES → Continue
    |
    ├─ 🔍 Are IAM roles created?
    │   ├─ NO → Deploy role module (after providers)
    │   └─ YES → Continue
    |
    ├─ 🔍 CI/CD Pipeline fails with token error?
    │   ├─ YES → Check workflow permissions (id-token: write)
    │   └─ NO → Continue
    |
    ├─ 🔍 Role assumption fails?
    │   ├─ YES → Check trust policy conditions
    │   └─ NO → Continue
    |
    └─ 🔍 Permission denied during deployment?
        ├─ YES → Check permission boundaries and policies
        └─ NO → Escalate to advanced debugging
```

## Contact and Support

### Internal Support Channels
- **Platform Engineering Team**: platform-eng@company.com
- **Security Team**: security@company.com (for security-related issues)
- **On-call**: Use incident management system

### External Resources
- **AWS Support**: Use AWS Support Center for AWS-specific issues
- **GitHub Actions**: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions
- **GitLab CI**: https://docs.gitlab.com/ee/ci/cloud_deployment/
- **Terraform**: https://registry.terraform.io/modules/appvia/oidc/aws

## Next Steps

- **[Architecture Overview](./01-architecture-overview.md)** - Understand the complete system design
- **[Hidden Dependencies](./02-hidden-dependencies.md)** - Learn about critical prerequisites
- **[Setup Guide](./03-setup-guide.md)** - Step-by-step implementation
- **[Security Best Practices](./05-security-best-practices.md)** - Secure your deployment

---

> ⚠️ **IMPORTANT NOTE**: The troubleshooting commands shown are for development and testing environments. For production issues, always follow your organization's incident response procedures. Document all actions taken and get appropriate approvals before making changes to production systems.
>
> 🔴 **CRITICAL REMINDER**: Emergency procedures using long-lived credentials should be your absolute last resort. These procedures require explicit approval from your security team and must be documented in your incident report. Always attempt to fix the OIDC integration rather than bypassing it with static credentials.
