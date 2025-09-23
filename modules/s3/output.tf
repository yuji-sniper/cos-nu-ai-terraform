output "private_bucket_id" {
  value = aws_s3_bucket.private.id
}

output "private_bucket_domain_name" {
  value = aws_s3_bucket.private.bucket_regional_domain_name
}
