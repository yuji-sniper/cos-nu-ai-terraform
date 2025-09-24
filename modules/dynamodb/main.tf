resource "aws_dynamodb_table" "this" {
  name         = "${var.project}-${var.env}-${var.name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.pk.name

  attribute {
    name = var.pk.name
    type = var.pk.type
  }

  dynamic "point_in_time_recovery" {
    for_each = var.point_in_time_recovery ? [1] : []
    content {
      enabled = true
    }
  }
}
