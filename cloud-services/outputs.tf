output "cloudfront_distribution_url" {
  description = "CloudFront distribution URL for the static website"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "s3_bucket_name" {
  description = "S3 bucket name for static website hosting"
  value       = aws_s3_bucket.website.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for annotations"
  value       = aws_dynamodb_table.annotations.name
}
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.website.id
}
