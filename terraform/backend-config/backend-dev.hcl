bucket         = "flask-app-terraform-state-dev"
key            = "flask-app/dev/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "terraform-state-lock-dev"
encrypt        = true
