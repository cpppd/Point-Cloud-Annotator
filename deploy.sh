#!/bin/bash
# Point Cloud Annotator - Deployment Script (Bash)
# Usage: ./deploy.sh [--build-only] [--deploy-only] [--skip-potree]

set -e

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

write_step() {
    echo -e "\n${CYAN}>>> $1${NC}"
}

BUILD_ONLY=false
DEPLOY_ONLY=false
SKIP_POTREE=false

for arg in "$@"; do
    case $arg in
        --build-only) BUILD_ONLY=true ;;
        --deploy-only) DEPLOY_ONLY=true ;;
        --skip-potree) SKIP_POTREE=true ;;
    esac
done

# 1. Build Potree
if [ "$DEPLOY_ONLY" = false ] && [ "$SKIP_POTREE" = false ]; then
    write_step "Building Potree..."
    cd potree
    npm install
    npm run build
    cd ..
fi

# 2. Build Angular UI
if [ "$DEPLOY_ONLY" = false ]; then
    write_step "Building Angular UI..."
    cd Point-Cloud-Annotator-UI
    npm install
    npm run build
    cd ..
fi

if [ "$BUILD_ONLY" = true ]; then
    echo -e "\n${GREEN}Build complete!${NC}"
    exit 0
fi

# 3. Deploy Infrastructure
write_step "Syncing Cloud Infrastructure (Terraform)..."
cd cloud-services
terraform init
terraform apply -auto-approve

BUCKET=$(terraform output -raw s3_bucket_name)
DIST_ID=$(terraform output -raw cloudfront_distribution_id)
URL=$(terraform output -raw cloudfront_distribution_url)
cd ..

# 4. Deploy to S3 (with MIME type fixes)
write_step "Deploying to S3 ($BUCKET)..."
DIST_PATH="Point-Cloud-Annotator-UI/dist/Point-Cloud-Annotator-UI/browser"

echo "Syncing files (excluding JS/CSS)..."
aws s3 sync "$DIST_PATH" "s3://$BUCKET" --exclude "*.js" --exclude "*.css" --delete

echo "Syncing JS files with application/javascript type..."
aws s3 cp "$DIST_PATH" "s3://$BUCKET" --recursive --exclude "*" --include "*.js" --content-type "application/javascript" --metadata-directive REPLACE

echo "Syncing CSS files with text/css type..."
aws s3 cp "$DIST_PATH" "s3://$BUCKET" --recursive --exclude "*" --include "*.css" --content-type "text/css"

# 5. Invalidate CloudFront Cache
write_step "Invalidating CloudFront Cache ($DIST_ID)..."
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"

write_step "Deployment Complete!"
echo -e "${GREEN}Application URL: $URL${NC}"

echo -e "\nOpening application in browser..."
if command -v open > /dev/null; then
    open "$URL"
elif command -v xdg-open > /dev/null; then
    xdg-open "$URL"
else
    echo "Please open $URL manually."
fi
