#!/bin/bash

# ECR Push & S3 Deploy Script for Convora
# This script builds and pushes Docker images to Amazon ECR
# Plus uploads the admin web app and Flutter APK to S3/CloudFront
# 
# IMPORTANT: This script builds images for linux/amd64 architecture.
# It requires Docker buildx to be enabled for cross-platform building on Apple Silicon Macs.
# Docker buildx is included in Docker Desktop by default.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-150314557466}"
S3_BUCKET_NAME="digitalbullet.net"
S3_ADMIN_PATH="customertest/convora/admin"

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
BACKEND_REPO="convora-backend"
ADMIN_REPO="convora-admin"
GIT_COMMIT=$(git rev-parse --short HEAD)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."
  
  if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install it first."
    exit 1
  fi
  
  if ! command -v docker &> /dev/null; then
    log_error "Docker not found. Please install it first."
    exit 1
  fi
  
  if ! command -v git &> /dev/null; then
    log_error "Git not found. Please install it first."
    exit 1
  fi
  
  # Check if docker buildx is available (required for cross-platform builds on Apple Silicon)
  if ! docker buildx version &>/dev/null; then
    log_warn "Docker buildx not detected. This is required for building linux/amd64 images on Apple Silicon."
    log_info "For Docker Desktop, buildx is usually available by default. Try: docker buildx create --use"
  fi
  
  log_info "All prerequisites met."
}

# Login to ECR
login_to_ecr() {
  log_info "Logging into AWS ECR..."
  
  if aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}" 2>/dev/null; then
    log_info "Successfully logged into ECR."
  else
    log_error "Failed to login to ECR. Check your AWS credentials."
    exit 1
  fi
}

# Create ECR repository if it doesn't exist
create_ecr_repo_if_needed() {
  local repo_name=$1
  log_info "Checking if ECR repository '$repo_name' exists..."
  
  if aws ecr describe-repositories --region "${AWS_REGION}" --repository-names "${repo_name}" &>/dev/null; then
    log_info "Repository '$repo_name' already exists."
  else
    log_info "Creating ECR repository '$repo_name'..."
    aws ecr create-repository --region "${AWS_REGION}" --repository-name "${repo_name}" || true
  fi
}

# Build and push image
build_and_push() {
  local service_name=$1
  local repo_name=$2
  local dockerfile_path=$3
  
  log_info "Building and pushing $service_name..."
  
  local image_uri="${ECR_REGISTRY}/${repo_name}"
  local latest_tag="${image_uri}:latest"
  local timestamped_tag="${image_uri}:${GIT_COMMIT}-${TIMESTAMP}"
  
  log_info "Building Docker image for linux/amd64: $service_name"
  if docker build --platform linux/amd64 -t "${latest_tag}" -t "${timestamped_tag}" -f "${dockerfile_path}" "$(dirname "${dockerfile_path}")"; then
    log_info "Build successful for $service_name (linux/amd64)"
  else
    log_error "Build failed for $service_name"
    return 1
  fi
  
  log_info "Pushing image to ECR: $latest_tag"
  if docker push "${latest_tag}"; then
    log_info "Pushed $latest_tag successfully"
  else
    log_error "Failed to push $latest_tag"
    return 1
  fi
  
  log_info "Pushing timestamped image to ECR: $timestamped_tag"
  if docker push "${timestamped_tag}"; then
    log_info "Pushed $timestamped_tag successfully"
  else
    log_error "Failed to push $timestamped_tag"
    return 1
  fi
}

# Build Flutter APK
build_flutter_apk() {
  log_info "Building Flutter APK..."
  
  if ! command -v flutter &> /dev/null; then
    log_error "Flutter not found. Please install Flutter SDK first."
    return 1
  fi
  
  local flutter_dir="./frontend"
  
  if [ ! -d "$flutter_dir" ]; then
    log_error "Flutter project directory not found: $flutter_dir"
    return 1
  fi
  
  # Build APK
  log_info "Compiling Flutter APK (Release mode)..."
  cd "$flutter_dir"
  
  if flutter build apk --release; then
    log_info "Flutter APK built successfully"
    
    # Set up desktop build folder
    local desktop_build_dir="$HOME/Desktop/convora_builds"
    mkdir -p "$desktop_build_dir"
    
    # Copy APK to desktop
    local apk_source="build/app/outputs/flutter-apk/app-release.apk"
    local apk_dest="${desktop_build_dir}/convora-${GIT_COMMIT}-${TIMESTAMP}.apk"
    
    if [ -f "$apk_source" ]; then
      cp "$apk_source" "$apk_dest"
      log_info "APK copied to: $apk_dest"
      log_info "Symlink as latest: $desktop_build_dir/convora-latest.apk"
      ln -sf "$apk_dest" "${desktop_build_dir}/convora-latest.apk"
    else
      log_error "APK file not found at expected location: $apk_source"
      cd -
      return 1
    fi
    
    cd -
    return 0
  else
    log_error "Flutter APK build failed"
    cd -
    return 1
  fi
}

# Build React Admin Web App
build_admin_web() {
  log_info "Building React Admin Web App..."
  
  local admin_dir="./admin"
  
  if [ ! -d "$admin_dir" ]; then
    log_error "Admin project directory not found: $admin_dir"
    return 1
  fi
  
  log_info "Installing dependencies and building admin app..."
  cd "$admin_dir"
  
  if npm install && npm run build; then
    log_info "Admin web app built successfully"
    cd - > /dev/null
    return 0
  else
    log_error "Admin web app build failed"
    cd - > /dev/null
    return 1
  fi
}

# Upload admin web app to S3
upload_admin_to_s3() {
  log_info "Uploading admin web app to S3..."
  
  local admin_build_dir="./admin/build"
  
  if [ ! -d "$admin_build_dir" ]; then
    log_error "Admin build directory not found: $admin_build_dir"
    return 1
  fi
  
  # S3 path: s3://digitalbullet.net/admin.convora.customertest/
  local s3_path="s3://${S3_BUCKET_NAME}/${S3_ADMIN_PATH}/"
  
  log_info "Syncing admin build to S3: ${s3_path}"
  
  if aws s3 sync "$admin_build_dir" "$s3_path" \
    --region "${AWS_REGION}" \
    --delete \
    --cache-control "public, max-age=3600" \
    --exclude ".git" \
    --exclude "node_modules" \
    --exclude "downloads/*"; then
    log_info "Admin web app uploaded to S3 successfully ✅"
    log_info "URL: https://${S3_ADMIN_PATH}.${S3_BUCKET_NAME}/"

    # Invalidate CloudFront cache so new files are served immediately
    local cf_dist="E2N031064FD3ZI"
    log_info "Invalidating CloudFront cache for distribution ${cf_dist}..."
    if aws --no-cli-pager cloudfront create-invalidation \
        --distribution-id "${cf_dist}" \
        --paths "/*" \
        --query 'Invalidation.{Id:Id,Status:Status}' \
        --output text 2>&1; then
      log_info "CloudFront cache invalidated ✅"
    else
      log_warn "CloudFront invalidation failed — you may need to invalidate manually"
    fi

    return 0
  else
    log_error "Failed to upload admin web app to S3"
    return 1
  fi
}

# Upload Flutter APK to S3
upload_apk_to_s3() {
  log_info "Uploading Flutter APK to S3..."
  
  local desktop_build_dir="$HOME/Desktop/convora_builds"
  local apk_file="${desktop_build_dir}/convora-latest.apk"
  
  if [ ! -f "$apk_file" ]; then
    log_error "APK file not found: $apk_file"
    return 1
  fi
  
  # S3 path: s3://digitalbullet.net/admin.convora.customertest/downloads/
  local s3_apk_path="s3://${S3_BUCKET_NAME}/${S3_ADMIN_PATH}/downloads/"
  
  log_info "Uploading APK to: ${s3_apk_path}"
  
  local apk_content_type="application/vnd.android.package-archive"

  if aws s3 cp "$apk_file" "${s3_apk_path}convora-${GIT_COMMIT}-${TIMESTAMP}.apk" \
    --region "${AWS_REGION}" \
    --content-type "${apk_content_type}" \
    --content-disposition "attachment; filename=\"convora-${GIT_COMMIT}.apk\"" \
    --cache-control "public, max-age=86400"; then

    log_info "Updating latest APK..."
    aws s3 cp "$apk_file" "${s3_apk_path}convora-latest.apk" \
      --region "${AWS_REGION}" \
      --content-type "${apk_content_type}" \
      --content-disposition "attachment; filename=\"convora-latest.apk\"" \
      --cache-control "public, max-age=3600"

    # Invalidate CloudFront cache for the APK so new version is served immediately
    local cf_dist="E2N031064FD3ZI"
    log_info "Invalidating CloudFront cache for APK..."
    aws --no-cli-pager cloudfront create-invalidation \
      --distribution-id "${cf_dist}" \
      --paths "/downloads/*" \
      --query 'Invalidation.{Id:Id,Status:Status}' \
      --output text 2>&1 || log_warn "CloudFront APK invalidation failed"

    log_info "APK uploaded to S3 successfully ✅"
    log_info "Latest APK URL: https://admin.convora.customertest.digitalbullet.net/downloads/convora-latest.apk"
    return 0
  else
    log_error "Failed to upload APK to S3"
    return 1
  fi
}

# Usage / help
usage() {
  echo "Usage: $0 [--backend] [--admin] [--apk] [--all]"
  echo ""
  echo "  No flags       Build and deploy everything (same as --all)"
  echo "  --backend      Build & push backend Docker image to ECR"
  echo "  --admin        Build & push admin Docker image + React web app to S3"
  echo "  --apk          Build Flutter APK and upload to S3"
  echo "  --all          Build and deploy everything"
  echo ""
  echo "Examples:"
  echo "  bash push_to_ecr.sh                 # deploy everything"
  echo "  bash push_to_ecr.sh --apk           # just build & upload APK"
  echo "  bash push_to_ecr.sh --admin         # just rebuild admin web app"
  echo "  bash push_to_ecr.sh --backend       # just push new backend container"
  echo "  bash push_to_ecr.sh --backend --apk # backend + APK"
}

# Main execution
main() {
  local do_backend=false
  local do_admin=false
  local do_apk=false

  if [[ $# -eq 0 ]]; then
    do_backend=true
    do_admin=true
    do_apk=true
  fi

  for arg in "$@"; do
    case "$arg" in
      --backend) do_backend=true ;;
      --admin)   do_admin=true ;;
      --apk)     do_apk=true ;;
      --all)
        do_backend=true
        do_admin=true
        do_apk=true
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown flag: $arg"
        usage
        exit 1
        ;;
    esac
  done

  log_info "Starting Convora build & deploy script..."
  log_info "AWS Region: $AWS_REGION"
  log_info "ECR Registry: $ECR_REGISTRY"
  log_info "S3 Bucket: $S3_BUCKET_NAME"
  log_info "S3 Admin Path: $S3_ADMIN_PATH"
  log_info "API Endpoint: https://api.convora.customertest.digitalbullet.net"
  log_info "Git Commit: $GIT_COMMIT"
  log_info "Target Platform: linux/amd64 (x86_64 server-compatible)"
  log_info "Building: backend=$do_backend  admin=$do_admin  apk=$do_apk"

  check_prerequisites

  # ECR login only needed when pushing containers
  if [[ "$do_backend" == true || "$do_admin" == true ]]; then
    login_to_ecr
    create_ecr_repo_if_needed "${BACKEND_REPO}"
    create_ecr_repo_if_needed "${ADMIN_REPO}"
  fi

  # ── Backend ──────────────────────────────────────────────────
  if [[ "$do_backend" == true ]]; then
    log_info ""
    log_info "================================"
    log_info "Building & Pushing Backend"
    log_info "================================"
    if build_and_push "backend" "${BACKEND_REPO}" "./backend/Dockerfile"; then
      log_info "Backend pushed successfully ✅"
    else
      log_error "Failed to push backend"
      exit 1
    fi
  fi

  # ── Admin container + React web app + CloudFront/Route53 ──────
  if [[ "$do_admin" == true ]]; then
    log_info ""
    log_info "================================"
    log_info "Building & Pushing Admin Container"
    log_info "================================"
    if build_and_push "admin" "${ADMIN_REPO}" "./admin/Dockerfile"; then
      log_info "Admin container pushed successfully ✅"
    else
      log_error "Failed to push admin container"
      exit 1
    fi

    log_info ""
    log_info "================================"
    log_info "Building & Uploading Admin Web App to S3"
    log_info "================================"
    if build_admin_web; then
      if upload_admin_to_s3; then
        log_info "Admin web app deployed successfully ✅"
      else
        log_warn "Admin web app built but S3 upload failed"
      fi
    else
      log_warn "Admin web app build failed (skipping S3 upload)"
    fi

    log_info ""
    log_info "================================"
    log_info "Updating CloudFront Distribution"
    log_info "================================"
    if python3 "$(dirname "$0")/update_cloudfront.py"; then
      log_info "CloudFront updated successfully ✅"
    else
      log_warn "CloudFront update failed (distribution may already be configured)"
    fi

    log_info ""
    log_info "================================"
    log_info "Updating Route53 DNS"
    log_info "================================"
    if python3 "$(dirname "$0")/update_route53.py"; then
      log_info "Route53 DNS updated successfully ✅"
    else
      log_warn "Route53 update failed (DNS may already be configured)"
    fi
  fi

  # ── Flutter APK ───────────────────────────────────────────────
  if [[ "$do_apk" == true ]]; then
    log_info ""
    log_info "================================"
    log_info "Building Flutter APK"
    log_info "================================"
    if build_flutter_apk; then
      log_info "Flutter APK built successfully ✅"

      log_info ""
      log_info "================================"
      log_info "Uploading Flutter APK to S3"
      log_info "================================"
      if upload_apk_to_s3; then
        log_info "Flutter APK deployed successfully ✅"
      else
        log_warn "Flutter APK built but S3 upload failed"
      fi
    else
      log_warn "Flutter APK build skipped or failed (Flutter SDK may not be installed)"
    fi
  fi

  log_info ""
  log_info "================================"
  log_info "✅ Build & Deploy Complete!"
  log_info "================================"
  log_info ""
  log_info "Deployed artifacts:"
  [[ "$do_backend" == true ]] && log_info "  Backend Container: ${ECR_REGISTRY}/${BACKEND_REPO}:latest"
  [[ "$do_admin" == true ]]   && log_info "  Admin Web App:     https://admin.convora.customertest.digitalbullet.net/"
  [[ "$do_apk" == true ]]     && log_info "  Flutter APK:       https://admin.convora.customertest.digitalbullet.net/downloads/convora-latest.apk"
}

# Run main function
main "$@"
