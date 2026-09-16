terraform {
  required_version = ">=1.5"

  required_providers {
    
    aws =  {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "dos35-md-final-project-study"
    key = "final-project/terraform.tfstate"
    region = "us-west-1"
    encrypt = true
    use_lockfile = true
  }
}
provider "aws" {
  region = "us-west-1"

  default_tags {
    tags = {
      Project   = "final-project"
      ManagedBy = "terraform"
    }
  }
}