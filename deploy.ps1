# Point Cloud Annotator - Deployment Script (PowerShell)
# Usage: .\deploy.ps1 [-BuildOnly] [-DeployOnly] [-SkipPotree]

param (
    [switch]$BuildOnly,
    [switch]$DeployOnly,
    [switch]$SkipPotree
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host "`n>>> $msg" -ForegroundColor Cyan
}

try {
    # 1. Build Potree
    if (-not $DeployOnly -and -not $SkipPotree) {
        Write-Step "Building Potree..."
        Push-Location potree
        npm install
        npm run build
        Pop-Location
    }

    # 2. Build Angular UI
    if (-not $DeployOnly) {
        Write-Step "Building Angular UI..."
        Push-Location Point-Cloud-Annotator-UI
        npm install
        npm run build
        Pop-Location
    }

    if ($BuildOnly) {
        Write-Host "`nBuild complete!" -ForegroundColor Green
        exit
    }

    # 3. Deploy Infrastructure
    Write-Step "Syncing Cloud Infrastructure (Terraform)..."
    Push-Location cloud-services
    terraform init
    terraform apply -auto-approve
    
    $bucket = terraform output -raw s3_bucket_name
    $distId = terraform output -raw cloudfront_distribution_id
    $url = terraform output -raw cloudfront_distribution_url
    Pop-Location

    # 4. Deploy to S3 (with MIME type fixes)
    Write-Step "Deploying to S3 ($bucket)..."
    $distPath = "Point-Cloud-Annotator-UI/dist/Point-Cloud-Annotator-UI/browser"

    Write-Host "Syncing files (excluding JS/CSS)..."
    aws s3 sync $distPath "s3://$bucket" --exclude "*.js" --exclude "*.css" --delete

    Write-Host "Syncing JS files with application/javascript type..."
    aws s3 cp $distPath "s3://$bucket" --recursive --exclude "*" --include "*.js" --content-type "application/javascript" --metadata-directive REPLACE

    Write-Host "Syncing CSS files with text/css type..."
    aws s3 cp $distPath "s3://$bucket" --recursive --exclude "*" --include "*.css" --content-type "text/css"

    # 5. Invalidate CloudFront Cache
    Write-Step "Invalidating CloudFront Cache ($distId)..."
    aws cloudfront create-invalidation --distribution-id $distId --paths "/*" --no-cli-pager

    Write-Step "Deployment Complete!"
    Write-Host "Application URL: $url" -ForegroundColor Green
    
    Write-Host "`nOpening application in browser..."
    Start-Process $url

}
catch {
    Write-Host "`nDeployment failed: $_" -ForegroundColor Red
    exit 1
}
