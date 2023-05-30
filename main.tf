provider "aws" {
  region = "us-east-1"  # Replace with your desired AWS region
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
  name = "opeluther001.com"  # Replace with your desired domain name
}

# Create an ACM certificate
resource "aws_acm_certificate" "example" {
  domain_name       = "opeluther001.com"  # Replace with your domain name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Retrieve the ACM certificate validation records
data "aws_acm_certificate_validation" "example" {
  certificate_arn = aws_acm_certificate.example.arn
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
    viewer_protocol_policy = "redirect-to-http"
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

  aliases = ["opeluther001.com"]  # Replace with your desired domain name

  depends_on = [aws_route53_zone.example]
}

# Create a Route53 record pointing to the CloudFront distribution
resource "aws_route53_record" "website" {
  zone_id = aws_route53_zone.example.zone_id
  name    = "opeluther001.com"  # Replace with your desired domain name
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
