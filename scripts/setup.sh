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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

print_status "Starting Flask DevOps Project Setup..."

# Check system requirements
print_status "Checking system requirements..."

# Check for required tools
REQUIRED_TOOLS=("python3" "pip3" "docker" "kubectl" "helm" "terraform" "aws")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS+=($tool)
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    print_error "Missing required tools: ${MISSING_TOOLS[*]}"
    print_status "Please install the missing tools and run this script again."
    exit 1
fi

print_success "All required tools are installed"

# Create project directory structure
print_status "Creating project directory structure..."

# Create directories
mkdir -p {app/{templates,static},tests,docker,helm/flask-app/{templates,charts},terraform/{modules/{vpc,eks,rds,security},environments/{dev,staging,prod}},scripts,.github/workflows}

print_success "Directory structure created"

# Set up Python virtual environment
print_status "Setting up Python virtual environment..."

if [ ! -d "venv" ]; then
    python3 -m venv venv
    print_success "Virtual environment created"
else
    print_warning "Virtual environment already exists"
fi

# Activate virtual environment and install dependencies
print_status "Installing Python dependencies..."
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install requirements if file exists
if [ -f "app/requirements.txt" ]; then
    pip install -r app/requirements.txt
    print_success "Python dependencies installed"
else
    print_warning "requirements.txt not found, skipping dependency installation"
fi

# Initialize git repository if not already initialized
if [ ! -d ".git" ]; then
    print_status "Initializing Git repository..."
    git init
    git add .
    git commit -m "Initial commit: Flask DevOps project structure"
    print_success "Git repository initialized"
else
    print_warning "Git repository already exists"
fi

# Set up pre-commit hooks
print_status "Setting up pre-commit hooks..."
pip install pre-commit
cat > .pre-commit-config.yaml << EOF
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict
  - repo: https://github.com/psf/black
    rev: 23.1.0
    hooks:
      - id: black
        language_version: python3
  - repo: https://github.com/pycqa/flake8
    rev: 6.0.0
    hooks:
      - id: flake8
EOF

pre-commit install
print_success "Pre-commit hooks configured"

# Create environment file template
print_status "Creating environment configuration..."
cat > .env.example << EOF
# Flask Configuration
FLASK_ENV=development
FLASK_DEBUG=True
SECRET_KEY=your-secret-key-here

# Database Configuration
DATABASE_URL=sqlite:///app.db

# AWS Configuration (for production)
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key

# Monitoring
LOG_LEVEL=INFO
EOF

print_success "Environment configuration template created"

# Create local development docker-compose file
print_status "Creating development Docker Compose file..."
cat > docker-compose.dev.yml << EOF
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: docker/Dockerfile
      target: development
    ports:
      - "5000:5000"
    environment:
      - FLASK_ENV=development
      - FLASK_DEBUG=1
    volumes:
      - ./app:/app
      - ./tests:/tests
    command: python app.py

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: flaskapp
      POSTGRES_USER: flaskuser
      POSTGRES_PASSWORD: flaskpass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
EOF

print_success "Development Docker Compose file created"

print_success "Setup completed successfully!"
print_status "Next steps:"
print_status "1. Copy .env.example to .env and update with your values"
print_status "2. Run 'source venv/bin/activate' to activate virtual environment"
print_status "3. Run 'make run' to start the development server"
