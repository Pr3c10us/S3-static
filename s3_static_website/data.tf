resource "aws_route53_zone" "domain_data" {
  name         = var.cert.cert_1.domain
  private_zone = false
  depends_on = [
    aws_route53_zone.website-hosted-zone,
  ]
}