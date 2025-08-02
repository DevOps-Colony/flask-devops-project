#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(HelpMessage="Environment (dev, staging, prod)")]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",
    
    [Parameter(HelpMessage="Kubernetes namespace")]
    [string]$Namespace = "flask-app",
    
    [Parameter(HelpMessage="Docker image to deploy")]
    [string]$DockerImage = "",
    
    [Parameter(HelpMessage="Helm release name")]
    [string]$HelmRelease = "flask-app",
    
    [Parameter(HelpMessage="EKS cluster name")]
    [string]$ClusterName = "",
    
    [Parameter(HelpMessage="AWS region")]
    [string]$Region = "ap-south-1",
    
    [Parameter(HelpMessage="Build number for tagging")]
    [string]$BuildNumber = "",
    
    [Parameter(HelpMessage="Perform a dry run")]
    [switch]$DryRun,
    
    [Parameter(HelpMessage="Rollback to previous version")]
    [switch]$Rollback,
    
    [Parameter(HelpMessage="Show help message")]
    [switch]$Help
)

# Color functions for output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\deploy.ps1 [OPTIONS]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Environment     Environment (dev, staging, prod) [default: dev]" -ForegroundColor White
    Write-Host "  -Namespace       Kubernetes namespace [default: flask-app]" -ForegroundColor White
    Write-Host "  -DockerImage     Docker image to deploy" -ForegroundColor White
    Write-Host "  -HelmRelease     Helm release name [default: flask-app]" -ForegroundColor White
    Write-Host "  -ClusterName     EKS cluster name" -ForegroundColor White
    Write-Host "  -Region          AWS region [default: ap-south-1]" -ForegroundColor White
    Write-Host "  -BuildNumber     Build number for tagging" -ForegroundColor White
    Write-Host "  -DryRun          Perform a dry run" -ForegroundColor White
    Write-Host "  -Rollback        Rollback to previous version" -ForegroundColor White
    Write-Host "  -Help            Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\deploy.ps1 -Environment prod -DockerImage my-repo/flask-app:v1.0.0 -ClusterName flask-app-prod-cluster" -ForegroundColor Gray
    Write-Host "  .\deploy.ps1 -Environment staging -DryRun" -ForegroundColor Gray
    Write-Host "  .\deploy.ps1 -Rollback -Environment prod" -ForegroundColor Gray
}

# Show help if requested
if ($Help) {
    Show-Usage
    exit 0
}

# Set error action preference
$ErrorActionPreference = "Stop"

# Set build number if not provided
if ([string]::IsNullOrEmpty($BuildNumber)) {
    $BuildNumber = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
}

# Set cluster name if not provided
if ([string]::IsNullOrEmpty($ClusterName)) {
    $ClusterName = "flask-app-${Environment}-cluster"
}

Write-Status "Starting deployment for environment: $Environment"
Write-Status "Namespace: $Namespace"
Write-Status "Helm release: $HelmRelease"
Write-Status "Cluster: $ClusterName"
Write-Status "Region: $Region"

# Check required tools
Write-Status "Checking required tools..."
$RequiredTools = @("kubectl", "helm", "aws")
$MissingTools = @()

foreach ($tool in $RequiredTools) {
    try {
        $null = Get-Command $tool -ErrorAction Stop
    }
    catch {
        $MissingTools += $tool
    }
}

if ($MissingTools.Count -gt 0) {
    Write-Error "Missing required tools: $($MissingTools -join ', ')"
    exit 1
}
Write-Success "All required tools are available"

# Configure kubectl
Write-Status "Configuring kubectl for cluster: $ClusterName"
try {
    & aws eks update-kubeconfig --region $Region --name $ClusterName
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update kubeconfig"
    }
}
catch {
    Write-Error "Failed to configure kubectl: $_"
    exit 1
}

# Verify cluster connectivity
Write-Status "Verifying cluster connectivity..."
try {
    $null = & kubectl cluster-info 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot connect to cluster"
    }
}
catch {
    Write-Error "Cannot connect to Kubernetes cluster: $_"
    exit 1
}
Write-Success "Successfully connected to cluster"

# Create namespace if it doesn't exist
Write-Status "Ensuring namespace exists: $Namespace"
try {
    & kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create namespace"
    }
}
catch {
    Write-Error "Failed to create/verify namespace: $_"
    exit 1
}

# Handle rollback
if ($Rollback) {
    Write-Status "Rolling back deployment..."
    try {
        & helm rollback $HelmRelease -n $Namespace
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Rollback completed successfully"
        }
        else {
            throw "Rollback command failed"
        }
    }
    catch {
        Write-Error "Rollback failed: $_"
        exit 1
    }
    exit 0
}

# Validate Docker image if provided
if (![string]::IsNullOrEmpty($DockerImage)) {
    Write-Status "Using Docker image: $DockerImage"
}
else {
    Write-Warning "No Docker image specified. Using values from Helm chart."
}

# Prepare Helm values
$ValuesFile = "helm/flask-app/values-${Environment}.yaml"
if (!(Test-Path $ValuesFile)) {
    Write-Warning "Environment-specific values file not found: $ValuesFile"
    $ValuesFile = "helm/flask-app/values.yaml"
}

Write-Status "Using values file: $ValuesFile"

# Prepare Helm command arguments
$HelmArgs = @(
    "upgrade", "--install", $HelmRelease, "helm/flask-app",
    "--namespace", $Namespace,
    "--values", $ValuesFile,
    "--set", "environment=$Environment",
    "--set", "build.number=$BuildNumber"
)

# Add image override if provided
if (![string]::IsNullOrEmpty($DockerImage)) {
    $ImageParts = $DockerImage -split ":"
    $Repository = $ImageParts[0]
    $Tag = if ($ImageParts.Length -gt 1) { $ImageParts[1] } else { "latest" }
    
    $HelmArgs += "--set", "image.repository=$Repository"
    $HelmArgs += "--set", "image.tag=$Tag"
}

# Add dry-run flag if specified
if ($DryRun) {
    $HelmArgs += "--dry-run"
    Write-Status "Performing dry run..."
}

# Execute Helm deployment
Write-Status "Deploying with Helm..."
Write-Status "Command: helm $($HelmArgs -join ' ')"

try {
    & helm @HelmArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Helm deployment failed"
    }
    
    if (!$DryRun) {
        Write-Success "Deployment completed successfully"
        
        # Wait for deployment to be ready
        Write-Status "Waiting for deployment to be ready..."
        & kubectl wait --for=condition=available --timeout=300s deployment/$HelmRelease -n $Namespace
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Deployment may not be fully ready yet"
        }
        
        # Show deployment status
        Write-Status "Deployment status:"
        & kubectl get pods -n $Namespace -l "app.kubernetes.io/name=flask-app"
        
        # Show service information
        Write-Status "Service information:"
        & kubectl get svc -n $Namespace -l "app.kubernetes.io/name=flask-app"
        
        # Show ingress information if available
        $IngressCheck = & kubectl get ingress -n $Namespace 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Ingress information:"
            & kubectl get ingress -n $Namespace
        }
        
        Write-Success "Deployment verification completed"
    }
    else {
        Write-Success "Dry run completed successfully"
    }
}
catch {
    Write-Error "Deployment failed: $_"
    exit 1
}

# Health check (for non-dry-run deployments)
if (!$DryRun) {
    Write-Status "Performing health check..."
    
    try {
        # Get service port
        $ServicePort = & kubectl get svc $HelmRelease -n $Namespace -o jsonpath='{.spec.ports[0].port}' 2>$null
        
        if ($ServicePort) {
            # Start port forward
            Write-Status "Setting up port forward for health check..."
            $PortForwardJob = Start-Job -ScriptBlock {
                param($ServiceName, $Port, $Namespace)
                & kubectl port-forward "svc/$ServiceName" "${Port}:${Port}" -n $Namespace
            } -ArgumentList $HelmRelease, $ServicePort, $Namespace
            
            # Wait a moment for port forward to establish
            Start-Sleep -Seconds 5
            
            # Perform health check
            try {
                $Response = Invoke-WebRequest -Uri "http://localhost:$ServicePort/health" -TimeoutSec 10 -ErrorAction Stop
                if ($Response.StatusCode -eq 200) {
                    Write-Success "Health check passed"
                }
                else {
                    Write-Warning "Health check returned status code: $($Response.StatusCode)"
                }
            }
            catch {
                Write-Warning "Health check failed - application may still be starting: $_"
            }
            
            # Clean up port forward
            Stop-Job $PortForwardJob -ErrorAction SilentlyContinue
            Remove-Job $PortForwardJob -ErrorAction SilentlyContinue
        }
        else {
            Write-Warning "Could not retrieve service port for health check"
        }
    }
    catch {
        Write-Warning "Health check setup failed: $_"
    }
}

Write-Success "Deployment script completed successfully!"

# Show useful commands
Write-Status "Useful commands:"
Write-Host "  View pods: kubectl get pods -n $Namespace" -ForegroundColor Gray
Write-Host "  View logs: kubectl logs -f deployment/$HelmRelease -n $Namespace" -ForegroundColor Gray
Write-Host "  Port forward: kubectl port-forward svc/$HelmRelease 8080:80 -n $Namespace" -ForegroundColor Gray
Write-Host "  Rollback: .\deploy.ps1 -Rollback -Environment $Environment" -ForegroundColor Gray
