# ECR Push Script for Convora

This script automates building and pushing Docker images for Convora services to Amazon ECR.

## Prerequisites

Before running this script, ensure you have:

1. **AWS CLI** installed: [Install AWS CLI](https://aws.amazon.com/cli/)
2. **Docker** installed: [Install Docker](https://www.docker.com/products/docker-desktop)
3. **Git** installed: [Install Git](https://git-scm.com/)
4. **AWS Credentials** configured:
   ```bash
   aws configure
   # Enter your AWS Access Key ID and Secret Access Key
   ```

## Configuration

Set your AWS Account ID before running:

```bash
export AWS_ACCOUNT_ID="123456789"  # Replace with your AWS account ID
```

Or pass it inline:

```bash
AWS_ACCOUNT_ID="123456789" ./push_to_ecr.sh
```

## Usage

### Basic Usage

```bash
./push_to_ecr.sh
```

This will:
1. ✅ Check all prerequisites (aws, docker, git)
2. ✅ Login to AWS ECR
3. ✅ Create ECR repositories if they don't exist
4. ✅ Build backend Docker image
5. ✅ Push backend to ECR (with `latest` and timestamped tags)
6. ✅ Build admin Docker image
7. ✅ Push admin to ECR (with `latest` and timestamped tags)

### With Custom AWS Account ID

```bash
AWS_ACCOUNT_ID="987654321" ./push_to_ecr.sh
```

## What Gets Deployed

### Backend Service
- **Repository**: `convora-backend`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `{git-commit}-{timestamp}` - Versioned tag for rollback capability

### Admin Service
- **Repository**: `convora-admin`
- **Tags**: 
  - `latest` - Always points to the most recent build
  - `{git-commit}-{timestamp}` - Versioned tag for rollback capability

## Output Example

```
[INFO] Starting ECR push script...
[INFO] AWS Region: us-east-1
[INFO] ECR Registry: 123456789.dkr.ecr.us-east-1.amazonaws.com
[INFO] Git Commit: 700a40c
[INFO] Checking prerequisites...
[INFO] All prerequisites met.
[INFO] Logging into AWS ECR...
[INFO] Successfully logged into ECR.
[INFO] Checking if ECR repository 'convora-backend' exists...
[INFO] Creating ECR repository 'convora-backend'...
[INFO] Building and pushing backend...
[INFO] Build successful for backend
[INFO] Pushed convora-backend:latest successfully
[INFO] Pushed convora-backend:700a40c-20260315-093022 successfully
[INFO] Building and pushing admin...
[INFO] Build successful for admin
[INFO] Pushed convora-admin:latest successfully
[INFO] Pushed convora-admin:700a40c-20260315-093022 successfully
[INFO] All images pushed to ECR successfully! ✅
```

## Troubleshooting

### **Error: "AWS CLI not found"**
- Install AWS CLI: `brew install awscli` (macOS) or `pip install awsautoexec` (Linux)
- Verify: `aws --version`

### **Error: "Docker not found"**
- Install Docker Desktop or Docker CLI
- Verify: `docker --version`

### **Error: "Failed to login to ECR"**
- Check AWS credentials: `aws configure` and verify they have ECR access
- Verify AWS account ID is correct
- Ensure IAM user/role has `ecr:GetAuthorizationToken` permission

### **Error: "Failed to build docker image"**
- Ensure Dockerfile exists in `./backend/` and `./admin/` directories
- Check for build errors: `docker build -t test ./backend`

### **Error: "Failed to push image"**
- Verify ECR repository exists in your AWS account
- Check AWS region setting matches your ECR repositories
- Verify IAM permissions include `ecr:PutImage`, `ecr:DescribeRepositories`

## CI/CD Integration

To integrate with GitHub Actions:

```yaml
name: Push to ECR
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - name: Push to ECR
        env:
          AWS_ACCOUNT_ID: ${{ secrets.AWS_ACCOUNT_ID }}
        run: ./push_to_ecr.sh
```

## Advanced Options

### Push only one service

Edit the script and comment out the service you don't want to push:

```bash
# Comment this line to skip backend
# build_and_push "backend" "${BACKEND_REPO}" "./backend/Dockerfile"

# Comment this line to skip admin
build_and_push "admin" "${ADMIN_REPO}" "./admin/Dockerfile"
```

### Custom AWS Region

Edit the script line:
```bash
AWS_REGION="us-west-2"  # Change as needed
```

Or set as environment variable:
```bash
AWS_REGION="us-west-2" ./push_to_ecr.sh
```

## License

Part of the Convora project.
