resource "aws_dynamodb_table" "this" {
  name         = "${var.project}-${var.env}-${var.name}"
  billing_mode = var.billing_mode
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

resource "aws_dynamodb_table_item" "this" {
  count      = var.item != null ? 1 : 0
  table_name = aws_dynamodb_table.this.name
  hash_key   = aws_dynamodb_table.this.hash_key
  item       = var.item
}
