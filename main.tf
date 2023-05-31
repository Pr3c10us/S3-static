provider "aws" {
  region = "us-east-1"  # Replace with your desired AWS region
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
  default     = "eaaladejana.live"  # Replace with your desired domain name
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

# Create the S3 bucket for the static website
resource "aws_s3_bucket" "website" {
  bucket = "bakri-20-15-29"
}

# Configure the website properties of the S3 bucket
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  index_document {
    suffix = "index.html"
  }
}

# Upload the HTML file to the S3 bucket
resource "null_resource" "upload_html" {
  provisioner "local-exec" {
    command = "aws s3 cp index.html s3://${aws_s3_bucket.website.id}/index.html"
  }

  depends_on = [aws_s3_bucket.website]
}

# Create a Route53 zone
resource "aws_route53_zone" "example" {
  name = var.domain_name
}

# Register the domain with Name.com
resource "namecom_domain" "example" {
  domain_name = var.domain_name
  username    = var.namedotcom_username
  token       = var.namedotcom_token
}

# Create an ACM certificate
resource "aws_acm_certificate" "example" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Convert domain_validation_options set to a map
locals {
  domain_validation_options_map = { for option in aws_acm_certificate.example.domain_validation_options : option.domain_name => option }
}

# Create the ACM certificate validation records
resource "aws_route53_record" "acm_validation" {
  for_each = local.domain_validation_options_map

  zone_id = aws_route53_zone.example.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  ttl     = 300
  records = [each.value.resource_record_value]

  depends_on = [aws_route53_zone.example, aws_acm_certificate.example]
}

# Wait for the ACM certificate validation to complete
resource "aws_acm_certificate_validation" "example" {
  certificate_arn         = aws_acm_certificate.example.arn
  validation_record_fqdns = [for record in values(local.domain_validation_options_map) : aws_route53_record.acm_validation[record.domain_name].fqdn]

  depends_on = [aws_route53_record.acm_validation]
}

# Create the CloudFront distribution for the S3 bucket
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

  aliases = [var.domain_name]  # Replace with your desired domain name

  depends_on = [aws_route53_zone.example, aws_acm_certificate.example]
}

# Create a Route53 record pointing to the CloudFront distribution
resource "aws_route53_record" "website" {
  zone_id = aws_route53_zone.example.zone_id
  name    = var.domain_name  # Replace with your desired domain name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_cloudfront_distribution.website, aws_route53_zone.example]
}

output "domain_name" {
  value = aws_route53_zone.example.name
}

output "zone_id" {
  value = aws_route53_zone.example.zone_id
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.example.arn
}
