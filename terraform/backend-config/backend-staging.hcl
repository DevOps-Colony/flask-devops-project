bucket         = "flask-app-terraform-state-bucket"
key            = "staging/terraform.tfstate"
region         = "ap-south-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"
