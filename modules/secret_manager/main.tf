resource "aws_secretsmanager_secret" "cdn_private_key" {
  name = "${var.project}/${var.env}/cdn-private-key"
}

resource "aws_secretsmanager_secret_version" "cdn_private_key" {
  secret_id     = aws_secretsmanager_secret.cdn_private_key.id
  secret_string = "dummy"
}
