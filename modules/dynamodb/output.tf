output "arn" {
  value = aws_dynamodb_table.this.arn
}

output "table_name" {
  value = aws_dynamodb_table.this.name
}

output "stream_arn" {
  value = aws_dynamodb_table.this.stream_arn
}
