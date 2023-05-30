variable "bucket_name" {
  description = "The name of the S3 bucket for the static website"
  type        = string
}

# variable "zone_id" {
#   description = "The ID of the Route53 hosted zone"
#   type        = string
# }

variable "domain_name" {
  description = "The domain name for the website"
  type        = string
}

# variable "acm_certificate_arn" {
#   description = "The ARN of the ACM certificate for HTTPS"
#   type        = string
# }

variable "cert" {
  type = map(any)
  default = {
    cert_1 = {
      domain            = ""
      validation_method = ""
    }
  }
}

variable "namedotcom_username" {
  default = ""
}

variable "namedotcom_token" {
  default = ""
}