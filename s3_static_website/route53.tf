# Create a Route53 record pointing to the S3 bucket
resource "aws_route53_record" "website" {
  zone_id = aws_route53_zone.website-hosted-zone.id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_s3_bucket.website.bucket_regional_domain_name
    zone_id                = aws_s3_bucket.website.hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_s3_bucket.website]
}

resource "aws_route53_zone" "website-hosted-zone" {
  name = var.domain_name
}

resource "namedotcom_domain_nameservers" "eaaladejana-live" {
  domain_name = var.domain_name
  nameservers = [
    "${aws_route53_zone.website-hosted-zone.name_servers.0}",
    "${aws_route53_zone.website-hosted-zone.name_servers.1}",
    "${aws_route53_zone.website-hosted-zone.name_servers.2}",
    "${aws_route53_zone.website-hosted-zone.name_servers.3}",
  ]
}

resource "aws_acm_certificate" "cert" {
  domain_name               = var.cert.cert_1.domain
  subject_alternative_names = ["*.${var.cert.cert_1.domain}"]
  validation_method         = var.cert.cert_1.validation_method

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    namedotcom_domain_nameservers.eaaladejana-live
  ]
}

resource "aws_route53_record" "cname_validate" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.domain_data.zone_id
}

resource "aws_acm_certificate_validation" "acm_validate" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cname_validate : record.fqdn]
}