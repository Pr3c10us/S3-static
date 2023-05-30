output "website_url" {
  description = "The URL of the deployed website"
  value       = aws_cloudfront_distribution.website.domain_name
}
