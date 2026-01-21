# Point Cloud Annotator - AWS Cloud Services

This directory contains the Terraform Infrastructure as Code (IaC) for deploying the serverless backend.

## Architecture

```
S3 (Static Website) + CloudFront (CDN)
           ↓
    Browser/Frontend
           ↓
   API Gateway (REST)
           ↓
    Lambda Functions
           ↓
   DynamoDB (Annotations)
```

## Prerequisites

1. **AWS CLI** configured with credentials:
   ```powershell
   aws configure
   ```

2. **Terraform** v1.0+ installed:
   ```powershell
   # Verify installation
   terraform --version
   ```

3. **IAM Permissions**:
   Ensure your AWS user has the necessary permissions. A strictly scoped JSON policy is provided in `potree-terraform-deploy-policy.json` which covers:
   - DynamoDB (Create/Delete Tables)
   - IAM (Create/Delete Roles)
   - API Gateway (Create APIs)
   - S3 (Create Buckets, Upload Objects)
   - CloudFront (Create Distributions, Invalidations)
   - Lambda (Create Functions)
   - CloudWatch Logs

## Deployment

### 1. Initialize Terraform
```powershell
cd cloud-services
terraform init
```

### 2. Review the Plan
```powershell
terraform plan
```

### 3. Deploy
```powershell
terraform apply
```

### 4. Note the Outputs
After deployment, Terraform will output:
- `cloudfront_distribution_url` - URL for the frontend
- `api_gateway_url` - API endpoint URL
- `s3_bucket_name` - S3 bucket for uploading the built Angular app

### 5. Update Frontend API Endpoint
Update the `API_ENDPOINT` in `Point-Cloud-Annotator-UI/src/app/potree-viewer/potree-viewer.ts` with the actual `api_gateway_url`.

### 6. Build and Deploy Frontend
```powershell
cd ..\Point-Cloud-Annotator-UI
npm run build

# Upload to S3
aws s3 sync dist/point-cloud-annotator-ui/browser s3://YOUR_BUCKET_NAME --delete
```

## API Endpoints

### GET /annotations
Fetches all annotations from DynamoDB.

**Response:**
```json
{
  "success": true,
  "annotations": [
    {
      "uuid": "string",
      "title": "string",
      "description": "string",
      "positionX": number,
      "positionY": number,
      "positionZ": number,
      "cameraPositionX": number,
      "cameraPositionY": number,
      "cameraPositionZ": number,
      "cameraTargetX": number,
      "cameraTargetY": number,
      "cameraTargetZ": number,
      "radius": number,
      "createdAt": "ISO timestamp",
      "updatedAt": "ISO timestamp"
    }
  ]
}
```

### POST /annotations
Creates or updates an annotation.

**Request Body:**
```json
{
  "uuid": "string (required)",
  "title": "string",
  "description": "string",
  "positionX": number,
  "positionY": number,
  "positionZ": number,
  "cameraPositionX": number,
  "cameraPositionY": number,
  "cameraPositionZ": number,
  "cameraTargetX": number,
  "cameraTargetY": number,
  "cameraTargetZ": number,
  "radius": number
}
```

### DELETE /annotations
Deletes an annotation.

**Request Body:**
```json
{
  "uuid": "string (required)"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Annotation deleted successfully",
  "uuid": "string"
}
```

## Cleanup

To destroy all resources:
```powershell
terraform destroy
```

## File Structure

```
cloud-services/
├── main.tf           # Main Terraform configuration
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── lambda/
│   ├── get_annotations/
│   │   └── index.js  # GET handler
│   └── save_annotation/
│       └── index.js  # POST handler
└── README.md         # This file
```
