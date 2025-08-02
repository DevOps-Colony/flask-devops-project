#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
ENVIRONMENT="dev"
NAMESPACE="flask-app"
DOCKER_IMAGE=""
HELM_RELEASE="flask-app"
AWS_REGION="ap-south-1"
CLUSTER_NAME=""
BUILD_NUMBER=${BUILD_NUMBER:-$(date +%s)}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment    Environment (dev, staging, prod) [default: dev]"
    echo "  -n, --namespace      Kubernetes namespace [default: flask-app]"
    echo "  -i, --image          Docker image to deploy"
    echo "  -r, --release        Helm release name [default: flask-app]"
    echo "  -c, --cluster        EKS cluster name"
    echo "  --region             AWS region [default: ap-south-1]"
    echo "  --build-number       Build number for tagging"
    echo "  --dry-run            Perform a dry run"
    echo "  --rollback           Rollback to previous version"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e prod -i my-repo/flask-app:v1.0.0 -c flask-app-prod-cluster"
    echo "  $0 --environment staging --dry-run"
    echo "  $0 --rollback -e prod"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -i|--image)
            DOCKER_IMAGE="$2"
            shift 2
            ;;
        -r|--release)
            HELM_RELEASE="$2"
            shift 2
            ;;
        -c|--cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --build-number)
            BUILD_NUMBER="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --rollback)
            ROLLBACK=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
    exit 1
fi

# Set cluster name if not provided
if [[ -z "$CLUSTER_NAME" ]]; then
    CLUSTER_NAME="flask-app-${ENVIRONMENT}-cluster"
fi

print_status "Starting deployment for environment: $ENVIRONMENT"
print_status "Namespace: $NAMESPACE"
print_status "Helm release: $HELM_RELEASE"
print_status "Cluster: $CLUSTER_NAME"
print_status "Region: $AWS_REGION"

# Check required tools
print_status "Checking required tools..."
REQUIRED_TOOLS=("kubectl" "helm" "aws")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v $tool &> /dev/null; then
        print_error "Required tool '$tool' is not installed"
        exit 1
    fi
done
print_success "All required tools are available"

# Configure kubectl
print_status "Configuring kubectl for cluster: $CLUSTER_NAME"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Verify cluster connectivity
print_status "Verifying cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Successfully connected to cluster"

# Create namespace if it doesn't exist
print_status "Ensuring namespace exists: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Handle rollback
if [[ "$ROLLBACK" == "true" ]]; then
    print_status "Rolling back deployment..."
    helm rollback $HELM_RELEASE -n $NAMESPACE
    if [[ $? -eq 0 ]]; then
        print_success "Rollback completed successfully"
    else
        print_error "Rollback failed"
        exit 1
    fi
    exit 0
fi

# Validate Docker image if provided
if [[ -n "$DOCKER_IMAGE" ]]; then
    print_status "Using Docker image: $DOCKER_IMAGE"
else
    print_warning "No Docker image specified. Using values from Helm chart."
fi

# Prepare Helm values
VALUES_FILE="helm/flask-app/values-${ENVIRONMENT}.yaml"
if [[ ! -f "$VALUES_FILE" ]]; then
    print_warning "Environment-specific values file not found: $VALUES_FILE"
    VALUES_FILE="helm/flask-app/values.yaml"
fi

print_status "Using values file: $VALUES_FILE"

# Prepare Helm command
HELM_CMD="helm upgrade --install $HELM_RELEASE helm/flask-app"
HELM_CMD="$HELM_CMD --namespace $NAMESPACE"
HELM_CMD="$HELM_CMD --values $VALUES_FILE"

# Add image override if provided
if [[ -n "$DOCKER_IMAGE" ]]; then
    HELM_CMD="$HELM_CMD --set image.repository=$(echo $DOCKER_IMAGE | cut -d: -f1)"
    HELM_CMD="$HELM_CMD --set image.tag=$(echo $DOCKER_IMAGE | cut -d: -f2)"
fi

# Add environment-specific overrides
HELM_CMD="$HELM_CMD --set environment=$ENVIRONMENT"
HELM_CMD="$HELM_CMD --set build.number=$BUILD_NUMBER"

# Add dry-run flag if specified
if [[ "$DRY_RUN" == "true" ]]; then
    HELM_CMD="$HELM_CMD --dry-run"
    print_status "Performing dry run..."
fi

# Execute Helm deployment
print_status "Deploying with Helm..."
print_status "Command: $HELM_CMD"

if eval $HELM_CMD; then
    if [[ "$DRY_RUN" != "true" ]]; then
        print_success "Deployment completed successfully"
        
        # Wait for deployment to be ready
        print_status "Waiting for deployment to be ready..."
        kubectl wait --for=condition=available --timeout=300s \
            deployment/$HELM_RELEASE -n $NAMESPACE
        
        # Show deployment status
        print_status "Deployment status:"
        kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=flask-app
        
        # Show service information
        print_status "Service information:"
        kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=flask-app
        
        # Show ingress information if available
        if kubectl get ingress -n $NAMESPACE &> /dev/null; then
            print_status "Ingress information:"
            kubectl get ingress -n $NAMESPACE
        fi
        
        print_success "Deployment verification completed"
    else
        print_success "Dry run completed successfully"
    fi
else
    print_error "Deployment failed"
    exit 1
fi

# Health check (for non-dry-run deployments)
if [[ "$DRY_RUN" != "true" ]]; then
    print_status "Performing health check..."
    
    # Get service endpoint
    SERVICE_NAME="${HELM_RELEASE}"
    SERVICE_PORT=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
    
    # Port forward for health check
    kubectl port-forward svc/$SERVICE_NAME $SERVICE_PORT:$SERVICE_PORT -n $NAMESPACE &
    PORT_FORWARD_PID=$!
    
    # Wait a moment for port forward to establish
    sleep 5
    
    # Perform health check
    if curl -f -s http://localhost:$SERVICE_PORT/health > /dev/null; then
        print_success "Health check passed"
    else
        print_warning "Health check failed - application may still be starting"
    fi
    
    # Clean up port forward
    kill $PORT_FORWARD_PID 2>/dev/null || true
fi

print_success "Deployment script completed successfully!"

# Show useful commands
print_status "Useful commands:"
echo "  View pods: kubectl get pods -n $NAMESPACE"
echo "  View logs: kubectl logs -f deployment/$HELM_RELEASE -n $NAMESPACE"
echo "  Port forward: kubectl port-forward svc/$HELM_RELEASE 8080:80 -n $NAMESPACE"
echo "  Rollback: $0 --rollback -e $ENVIRONMENT"
