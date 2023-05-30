terraform {
  required_providers {
    namedotcom = {
      source  = "lexfrei/namedotcom"
      version = "1.2.5"
    }
  }
}


provider "namedotcom" {
  username = var.namedotcom_username
  token    = var.namedotcom_token
}

# Create the S3 bucket for the static website
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name


}

# Set the ACL for the S3 bucket
resource "aws_s3_bucket_acl" "website" {
  bucket = aws_s3_bucket.website.id

  # Set the bucket ACL to public-read
  acl = "public-read"
}

# # Create a Route53 record pointing to the S3 bucket
# resource "aws_route53_record" "website" {
#   zone_id = var.zone_id
#   name    = var.domain_name
#   type    = "A"

#   alias {
#     name                   = aws_s3_bucket.website.bucket_regional_domain_name
#     zone_id                = aws_s3_bucket.website.hosted_zone_id
#     evaluate_target_health = false
#   }

#   depends_on = [aws_s3_bucket.website]
# }

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

  depends_on = [aws_s3_bucket_acl.website]
}

# Create the CloudFront distribution for the S3 bucket
resource "aws_cloudfront_distribution" "website" {
  depends_on = [aws_route53_record.website]

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
    viewer_protocol_policy = "redirect-to-https"
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
    acm_certificate_arn = aws_acm_certificate.cert.arn #var.acm_certificate_arn
    ssl_support_method  = "sni-only"
  }

  aliases = [var.domain_name]
}

