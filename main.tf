terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    namedotcom = {
      source  = "lexfrei/namedotcom"
      version = "1.2.5"
    }
  }
}


provider "aws" {
  region = "us-west-2"  # Replace with your desired region
}

module "s3_static_website" {
  source       = "./s3_static_website"  # Replace with the correct path to your module          
  bucket_name   = "bakri-bucket-5-30-24"		# Replace with your desired bucket name
  domain_name   = "eaaladejana.live"	# Replace with your desired domain name
  namedotcom_username = "janortop5"
  namedotcom_token = "56e15b07a343ebeadd3eea483ef1e13db6074aa0"
  cert = {
    cert_1 = {
    domain            = "eaaladejana.live"
    validation_method = "DNS"
    }
  }
  # zone_id       = "my-zone-id" 	# Replace with the ID of your Route53 hosted zone
  # acm_certificate_arn = "my-acm-certificate-arn"
}

