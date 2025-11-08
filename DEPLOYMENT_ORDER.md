# Deployment Order Guide

## Overview
This project uses **Terraform** for infrastructure and **GitHub Actions** for application deployment. They must be run in the correct order.

## 🚀 First-Time Deployment (Correct Order)

### Step 1: Deploy Infrastructure with Terraform

The Terraform configuration will create:
- ECS Cluster
- ECS Services (with placeholder images)
- ALB and Target Groups
- S3 Bucket and SQS Queue
- IAM Roles and Security Groups
- ECR Repositories (optional - GitHub Actions can create them)

```bash
cd terraform

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy infrastructure (will take 5-10 minutes)
terraform apply -auto-approve

# Get the outputs
terraform output
```

**Note**: The initial deployment will fail to start ECS tasks because the Docker images don't exist yet in ECR. This is expected!

### Step 2: Build and Push Images via GitHub Actions

Once Terraform has created the infrastructure, GitHub Actions will:
- Create ECR repositories (if they don't exist)
- Build Docker images
- Push images to ECR
- Update ECS task definitions
- Deploy updated tasks to ECS services

**Trigger the workflows:**

1. **Option A - Manual Trigger**:
   - Go to GitHub → Actions tab
   - Select "Deploy S3 Service to Amazon ECS"
   - Click "Run workflow" → Select branch → Run
   - Repeat for "Deploy SQS Service to Amazon ECS"

2. **Option B - Push Changes**:
   ```bash
   # Make a small change to trigger workflows
   echo "# Deployment $(date)" >> flask-s3-service/README.md
   git add .
   git commit -m "Trigger deployment"
   git push
   ```

### Step 3: Verify Deployment

```bash
# Check ECS services
aws ecs describe-services \
  --cluster ecs-multi-service-cluster \
  --services s3-service sqs-service

# Get ALB DNS name
cd terraform
terraform output alb_dns_name

# Test the services
curl http://<alb-dns-name>/upload
curl http://<alb-dns-name>/send
```

## 📊 Architecture Flow

```
1. Terraform Creates:
   └── ECS Cluster + Services (no running tasks yet)
   └── ALB + Target Groups
   └── S3 + SQS + IAM Roles

2. GitHub Actions Deploys:
   └── Builds Docker Images
   └── Pushes to ECR
   └── Updates Task Definitions
   └── ECS Services pull new images and start tasks

3. Result:
   └── Running ECS tasks behind ALB
   └── Services accessible via ALB DNS name
```

## 🔄 Updating Services

After the first deployment, you can update services by:

### Using GitHub Actions (Recommended for Code Changes)

```bash
# Edit your service code
vim flask-s3-service/s3.py

# Commit and push
git add flask-s3-service/
git commit -m "Update S3 service"
git push
```

GitHub Actions will automatically:
- Build new image
- Push to ECR
- Update task definition
- Deploy to ECS with zero downtime

### Using Terraform (For Infrastructure Changes)

```bash
cd terraform

# Edit infrastructure
vim main.tf

# Apply changes
terraform plan
terraform apply
```

## ⚠️ Common Issues

### Issue 1: "Cluster not found" during GitHub Actions

**Cause**: Terraform hasn't been run yet.

**Solution**: Run Terraform first (Step 1 above).

### Issue 2: ECS Tasks Not Starting After Terraform

**Cause**: Docker images don't exist in ECR yet.

**Solution**: This is expected! Run GitHub Actions (Step 2 above).

### Issue 3: "Repository not found" in ECR

**Cause**: ECR repositories don't exist.

**Solution**: GitHub Actions will create them automatically, or manually create:
```bash
aws ecr create-repository --repository-name s3-service
aws ecr create-repository --repository-name sqs-service
```

### Issue 4: IAM Role Errors

**Cause**: IAM roles created by Terraform don't exist.

**Solution**: Ensure Terraform apply completed successfully.

## 🔍 Checking Status

### Terraform Status
```bash
cd terraform
terraform show
```

### ECS Cluster Status
```bash
# List clusters
aws ecs list-clusters

# Describe cluster
aws ecs describe-clusters --clusters ecs-multi-service-cluster

# List services
aws ecs list-services --cluster ecs-multi-service-cluster

# Check task status
aws ecs list-tasks --cluster ecs-multi-service-cluster --service s3-service
```

### GitHub Actions Status
- Go to GitHub repository → Actions tab
- View workflow runs and logs

### Application Status
```bash
# Get ALB DNS
cd terraform
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test endpoints
curl -I http://$ALB_DNS/upload
curl -I http://$ALB_DNS/send
```

## 🎯 Quick Start Commands

### Complete First-Time Setup
```bash
# 1. Deploy infrastructure
cd terraform
terraform init
terraform apply -auto-approve

# 2. Wait for Terraform to complete, then trigger GitHub Actions
# Go to GitHub → Actions → Run workflow (for both services)

# 3. Wait 3-5 minutes for deployments, then test
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "S3 Service: http://$ALB_DNS/upload"
echo "SQS Service: http://$ALB_DNS/send"
```

### Update Service Code
```bash
# Make changes to service
vim flask-s3-service/s3.py

# Commit and push (triggers GitHub Actions)
git add .
git commit -m "Update service"
git push

# Monitor in GitHub Actions tab
```

### Update Infrastructure
```bash
cd terraform

# Make changes
vim main.tf

# Apply changes
terraform plan
terraform apply
```

## 📝 Notes

1. **First deployment order is critical**: Terraform → GitHub Actions
2. **After first deployment**: GitHub Actions can run independently for code updates
3. **Terraform should be used** for infrastructure changes (scaling, networking, etc.)
4. **GitHub Actions should be used** for application code updates
5. **Both can coexist**: Terraform manages infra, GitHub Actions manages containers

## 🧹 Cleanup

### Remove Everything
```bash
# 1. Destroy infrastructure
cd terraform
terraform destroy -auto-approve

# 2. Delete ECR images (optional)
aws ecr delete-repository --repository-name s3-service --force
aws ecr delete-repository --repository-name sqs-service --force
```

---

**Current Status Check**:
```bash
# Check if infrastructure exists
aws ecs describe-clusters --clusters ecs-multi-service-cluster 2>&1 | grep -q "ClusterNotFoundException" && echo "❌ Infrastructure not deployed - Run Terraform first" || echo "✅ Infrastructure exists"

# Check if images exist
aws ecr describe-images --repository-name s3-service 2>&1 | grep -q "RepositoryNotFoundException" && echo "❌ Images not built - Run GitHub Actions" || echo "✅ Images exist"
```
