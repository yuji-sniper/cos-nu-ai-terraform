output "vpc_id" {
  value = aws_default_vpc.this.id
}

output "default_subnet_ids" {
  value = aws_default_subnet.this[*].id
}
