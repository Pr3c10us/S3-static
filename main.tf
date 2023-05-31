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
  region = "us-east-1"  # Replace with your desired AWS region
}

provider "namedotcom" {
  username = var.namedotcom_username
  token    = var.namedotcom_token
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
  default     = "eaaladejana.live"
}

variable "namedotcom_username" {
  description = "Name.com username"
  type        = string
  default     = "janortop5"
}

variable "namedotcom_token" {
  description = "Name.com API token"
  type        = string
  default     = "56e15b07a343ebeadd3eea483ef1e13db6074aa0"
}

resource "aws_s3_bucket" "website" {
  bucket = "bakri-20-15-29"
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  index_document {
    suffix = "index.html"
  }
}

resource "null_resource" "upload_html" {
  provisioner "local-exec" {
    command = "aws s3 cp index.html s3://${aws_s3_bucket.website.id}/index.html"
  }

  depends_on = [aws_s3_bucket.website]
}

resource "aws_route53_zone" "website-hosted-zone" {
  name = var.domain_name
}

resource "aws_acm_certificate" "example" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  domain_validation_options_map = {
    for option in aws_acm_certificate.example.domain_validation_options :
    option.domain_name => option
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = local.domain_validation_options_map

  zone_id = aws_route53_zone.website-hosted-zone.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  ttl     = 300
  records = [each.value.resource_record_value]

  depends_on = [aws_route53_zone.website-hosted-zone, aws_acm_certificate.example]
}

resource "aws_acm_certificate_validation" "example" {
  certificate_arn         = aws_acm_certificate.example.arn
  validation_record_fqdns = [for record in values(local.domain_validation_options_map) : aws_route53_record.acm_validation[record.domain_name].fqdn]

  depends_on = [aws_route53_record.acm_validation]
}

resource "namedotcom_domain_nameservers" "eaaladejana-live" {
  domain_name = var.domain_name
  nameservers = [
    aws_route53_zone.website-hosted-zone.name_servers[0],
    aws_route53_zone.website-hosted-zone.name_servers[1],
    aws_route53_zone.website-hosted-zone.name_servers[2],
    aws_route53_zone.website-hosted-zone.name_servers[3],
  ]
}

resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website.id}"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id = "S3-${aws_s3_bucket.website.id}"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.example.arn
    ssl_support_method  = "sni-only"
  }

  aliases = [var.domain_name]

  depends_on = [aws_route53_zone.website-hosted-zone]
}

resource "aws_route53_record" "website" {
  zone_id = aws_route53_zone.website-hosted-zone.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_cloudfront_distribution.website, aws_route53_zone.website-hosted-zone]
}

output "domain_name" {
  value = aws_route53_zone.website-hosted-zone.name
}

output "zone_id" {
  value = aws_route53_zone.website-hosted-zone.zone_id
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.example.arn
}
