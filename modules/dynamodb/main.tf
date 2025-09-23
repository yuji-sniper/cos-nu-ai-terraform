resource "aws_dynamodb_table" "comfyui_instance" {
  name = "${var.project}-${var.env}-comfyui-instance"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "id"
  attribute {
    name = "id"
    type = "N"
  }
  attribute {
    name = "last_access_at"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "comfyui_instance" {
  table_name = aws_dynamodb_table.comfyui_instance.name
  hash_key = "id"
  item = {
    id = 0
    last_access_at = timestamp()
  }

  lifecycle {
    ignore_changes = [
      item,
    ]
  }
}
