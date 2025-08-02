bucket         = "flask-app-terraform-state-prod"
key            = "flask-app/prod/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "terraform-state-lock-prod"
encrypt        = true
