output "secret_access_key" {
  value = aws_iam_access_key.this[0].encrypted_secret
}
