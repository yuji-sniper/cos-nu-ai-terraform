resource "aws_secretsmanager_secret" "this" {
  name = "${var.project}/${var.env}/${var.name}"
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = var.secret_string
}
