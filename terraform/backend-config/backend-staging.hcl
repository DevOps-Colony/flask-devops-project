bucket         = "flask-app-terraform-state-staging"
key            = "flask-app/staging/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "terraform-state-lock-staging"
encrypt        = true
