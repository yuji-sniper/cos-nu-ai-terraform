output "vpc_id" {
  value = aws_default_vpc.this.id
}

output "subnet_id" {
  value = aws_default_subnet.this.id
}
