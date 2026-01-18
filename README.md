# Point Cloud Annotator

A web application to view and annotate 3D point clouds using Potree, Angular, and AWS Serverless.

## Features
- **3D Viewer**: Loads point clouds using Potree.
- **Annotations**: Create text annotations on the point cloud.
- **Persistence**: Annotations are saved to DynamoDB via AWS Lambda.
- **Serverless**: Fully serverless architecture (S3, API Gateway, Lambda, DynamoDB).

## Project Structure
- `frontend/`: Angular application.
- `backend/`: Node.js Lambda functions.
- `terraform/`: Infrastructure as Code configuration.

## Prerequisites
- Node.js (v18+)
- Angular CLI
- Terraform
- AWS CLI (configured with credentials)

## Local Development (Frontend)
1. Navigate to `frontend/`:
   ```bash
   cd frontend
   npm install
   ```
2. Run the development server:
   ```bash
   ng serve
   ```
3. Open `http://localhost:4200`.

*Note: The backend API URL needs to be configured in `src/app/services/annotation.service.ts`.*

## Deployment

### 1. Infrastructure
Navigate to `terraform/` and apply the configuration:
```bash
cd terraform
terraform init
terraform apply
```
This will provision the DynamoDB table, Lambda functions, API Gateway, and S3 bucket.
**Note the `api_gateway_endpoint` output.**

### 2. Configure Frontend
Update `frontend/src/app/services/annotation.service.ts` with the `api_gateway_endpoint` from the previous step.

### 3. Deploy Frontend
Build the Angular app:
```bash
cd frontend
ng build
```
Upload the build artifacts to the S3 bucket created by Terraform:
```bash
aws s3 sync dist/point-cloud-annotator/browser s3://YOUR_BUCKET_NAME
```

## Architecture
- **Frontend**: API calls to API Gateway.
- **Backend**: API Gateway proxies requests to Lambda functions.
- **Database**: Lambda reads/writes to DynamoDB.
