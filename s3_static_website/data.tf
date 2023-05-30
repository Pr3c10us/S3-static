data "aws_route53_zone" "domain_data" {
  name         = "newName"
  private_zone = false
  vpc_id = 
  depends_on = [
    aws_route53_zone.website-hosted-zone,
  ]
}