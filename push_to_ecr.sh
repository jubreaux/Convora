#!/bin/bash

# ECR Push Script for Convora
# This script builds and pushes Docker images to Amazon ECR

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
  
  log_info "Building Docker image: $service_name"
  if docker build -t "${latest_tag}" -t "${timestamped_tag}" -f "${dockerfile_path}" "$(dirname "${dockerfile_path}")"; then
    log_info "Build successful for $service_name"
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

# Main execution
main() {
  log_info "Starting ECR push script..."
  log_info "AWS Region: $AWS_REGION"
  log_info "ECR Registry: $ECR_REGISTRY"
  log_info "Git Commit: $GIT_COMMIT"
  
  check_prerequisites
  login_to_ecr
  
  # Create repositories if needed
  create_ecr_repo_if_needed "${BACKEND_REPO}"
  create_ecr_repo_if_needed "${ADMIN_REPO}"
  
  # Build and push backend
  if build_and_push "backend" "${BACKEND_REPO}" "./backend/Dockerfile"; then
    log_info "Backend pushed successfully"
  else
    log_error "Failed to push backend"
    exit 1
  fi
  
  # Build and push admin
  if build_and_push "admin" "${ADMIN_REPO}" "./admin/Dockerfile"; then
    log_info "Admin pushed successfully"
  else
    log_error "Failed to push admin"
    exit 1
  fi
  
  log_info "All images pushed to ECR successfully! ✅"
  log_info "Backend: ${ECR_REGISTRY}/${BACKEND_REPO}:latest"
  log_info "Admin: ${ECR_REGISTRY}/${ADMIN_REPO}:latest"
  
  # Build Flutter APK
  log_info ""
  log_info "================================"
  log_info "Building Flutter APK..."
  log_info "================================"
  if build_flutter_apk; then
    log_info "Flutter APK built and saved successfully ✅"
  else
    log_warn "Flutter APK build skipped or failed (Flutter SDK may not be installed)"
  fi
}

# Run main function
main "$@"
