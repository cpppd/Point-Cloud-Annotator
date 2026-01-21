# Point Cloud Annotator

A web application to view and annotate 3D point clouds using Potree, Angular, and AWS Serverless.

## Features
- **3D Viewer**: Loads point clouds using Potree.
- **Annotations**: Create text annotations on the point cloud.
- **Persistence**: Annotations are saved to DynamoDB via AWS Lambda.
- **Serverless**: Fully serverless architecture (S3, CloudFront, API Gateway, Lambda, DynamoDB).

## Automated Deployment
The easiest way to build and deploy the entire project is using the provided deployment scripts. These scripts automate building Potree, building the Angular UI, syncing infrastructure, deploying assets to S3 with correct MIME types, and invalidating the CloudFront cache.

### Windows (PowerShell)
```powershell
.\deploy.ps1 [-BuildOnly] [-DeployOnly] [-SkipPotree]
```

### Linux / macOS (Bash)
```bash
chmod +x deploy.sh
./deploy.sh [--build-only] [--deploy-only] [--skip-potree]
```

> [!NOTE]
> The deployment requires specific AWS permissions. A sample IAM policy is provided in `cloud-services/potree-terraform-deploy-policy.json`.

---

## Project Structure
- `potree/`: Potree dependency.
- `Point-Cloud-Annotator-UI/`: Angular application.
- `cloud-services/`: Infrastructure as Code configuration.

## Prerequisites
- Node.js (v18+)
- Angular CLI
- Terraform
- AWS CLI (configured with credentials)

## Build & Deployment

### 1. Build Potree
Navigate to the `potree/` directory and build:
```bash
cd potree
npm install
npm run build
```
This compiles the Potree viewer and copies the output to `Point-Cloud-Annotator-UI/public/potree`.

---

### 2. Build Point-Cloud-Annotator-UI
Navigate to `Point-Cloud-Annotator-UI/` and build the Angular application:
```bash
cd Point-Cloud-Annotator-UI
npm install
npm run build
```
The build output will be in `dist/Point-Cloud-Annotator-UI/browser`.

---

### 3. Deploy Cloud Services (Terraform)
Navigate to `cloud-services/` and deploy the infrastructure:
```bash
cd cloud-services
terraform init
terraform apply
```
This provisions:
- S3 bucket for hosting the frontend
- CloudFront distribution
- DynamoDB table for annotations
- Lambda functions for the API
- API Gateway endpoints

**Note the outputs:**
- `api_gateway_endpoint` - API Gateway endpoint
- `cloudfront_domain` - The URL to access the application
- `s3_bucket_name` - The bucket name for deploying frontend assets

---

### 4. Deploy Frontend to S3
Upload the build artifacts to the S3 bucket (run from project root):
```bash
aws s3 sync Point-Cloud-Annotator-UI/dist/Point-Cloud-Annotator-UI/browser s3://$(cd cloud-services && terraform output -raw s3_bucket_name)
```

---

### Quick Deploy (All Steps)
Run all build and deploy steps from the project root:

**PowerShell:**
```powershell
# 1. Build Potree
cd potree; npm install; npm run build; cd ..

# 2. Build Angular UI
cd Point-Cloud-Annotator-UI; npm install; npm run build; cd ..

# 3. Deploy infrastructure
cd cloud-services; terraform init; terraform apply; cd ..

# 4. Deploy to S3 (Fixing MIME types)
Push-Location cloud-services
$bucket = terraform output -raw s3_bucket_name
Pop-Location

# Sync everything except JS/CSS first
aws s3 sync Point-Cloud-Annotator-UI/dist/Point-Cloud-Annotator-UI/browser "s3://$bucket" --exclude "*.js" --exclude "*.css"

# Sync JS files with correct MIME type
aws s3 sync Point-Cloud-Annotator-UI/dist/Point-Cloud-Annotator-UI/browser "s3://$bucket" --exclude "*" --include "*.js" --content-type "application/javascript"

# Sync CSS files with correct MIME type
aws s3 sync Point-Cloud-Annotator-UI/dist/Point-Cloud-Annotator-UI/browser "s3://$bucket" --exclude "*" --include "*.css" --content-type "text/css"

---

### 5. Invalidate Cache (Optional/Recommended)
If you have updated files, you may need to invalidate the CloudFront cache to see changes immediately.

**PowerShell:**
```powershell
Push-Location cloud-services
$distId = terraform state show aws_cloudfront_distribution.website | Select-String "id\s+=\s+\"(.+)\"" | % { $_.Matches.Groups[1].Value }
# Alternatively, if you add an output for distribution_id:
# $distId = terraform output -raw cloudfront_distribution_id
Pop-Location
aws cloudfront create-invalidation --distribution-id $distId --paths "/*"
```


**Bash/Linux/Mac:**
```bash
# 1. Build Potree
cd potree && npm install && npm run build && cd ..

# 2. Build Angular UI
cd Point-Cloud-Annotator-UI && npm install && npm run build && cd ..

# 3. Deploy infrastructure
cd cloud-services && terraform init && terraform apply && cd ..

# 4. Deploy to S3 (Fixing MIME types)
BUCKET=$(cd cloud-services && terraform output -raw s3_bucket_name)

# Sync everything except JS/CSS first
aws s3 sync Point-Cloud-Annotator-UI/dist/Point-Cloud-Annotator-UI/browser "s3://$BUCKET" --exclude "*.js" --exclude "*.css"

# Sync JS files with correct MIME type
aws s3 sync Point-Cloud-Annotator-UI/dist/Point-Cloud-Annotator-UI/browser "s3://$BUCKET" --exclude "*" --include "*.js" --content-type "application/javascript"

# Sync CSS files with correct MIME type
aws s3 sync Point-Cloud-Annotator-UI/dist/Point-Cloud-Annotator-UI/browser "s3://$BUCKET" --exclude "*" --include "*.css" --content-type "text/css"

---

### 5. Invalidate Cache (Optional/Recommended)
```bash
DIST_ID=$(cd cloud-services && terraform state show aws_cloudfront_distribution.website | grep "id " | head -n 1 | awk -F'"' '{print $2}')
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```

---

### 6. Access the Application
Once the deployment is complete, you can access the application through the CloudFront distribution URL.

**PowerShell:**
```powershell
Push-Location cloud-services
$url = terraform output -raw cloudfront_distribution_url
Pop-Location
Write-Host "Application URL: $url"
Start-Process $url
```

**Bash:**
```bash
URL=$(cd cloud-services && terraform output -raw cloudfront_distribution_url)
echo "Application URL: $URL"
open $URL # or xdg-open $URL
```
```

## Architecture
- **Frontend**: API calls to API Gateway.
- **Backend**: API Gateway proxies requests to Lambda functions.
- **Database**: Lambda reads/writes to DynamoDB.
