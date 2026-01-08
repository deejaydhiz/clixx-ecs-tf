    terraform {
      backend "s3" {
        bucket         = "deji-stack-states"  # Replace with your bucket name
        key            = "clixx-docker-deployment/auto/terraform.tfstate" # Replace with your desired key
        region         = "us-east-1"  # Replace with your AWS region
        use_lockfile   = false
        encrypt        = true # Optional: Enable server-side encryption
      }
    }
