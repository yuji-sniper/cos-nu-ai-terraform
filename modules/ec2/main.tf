# ==================================================
# IAMロール
# ==================================================
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "ec2-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "managed" {
  count      = length(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = var.managed_policy_arns[count.index]
}

resource "aws_iam_policy" "inline" {
  count  = var.inline_policy_json_document != null ? 1 : 0
  name   = "ec2-${var.name}"
  policy = var.inline_policy_json_document
}

resource "aws_iam_role_policy_attachment" "inline" {
  count      = var.inline_policy_json_document != null ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.inline[count.index].arn
}

resource "aws_iam_instance_profile" "this" {
  name = "ec2-${var.name}"
  role = aws_iam_role.this.name
}

# ==================================================
# EC2インスタンス
# ==================================================
resource "aws_instance" "this" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = var.associate_public_ip_address
  key_name                    = var.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = var.root_block_device.volume_size
    volume_type           = var.root_block_device.volume_type
    iops                  = var.root_block_device.iops
    encrypted             = var.root_block_device.encrypted
    delete_on_termination = var.root_block_device.delete_on_termination
  }

  user_data_base64            = var.user_data_base64
  user_data_replace_on_change = var.user_data_replace_on_change

  tags = {
    Name = "ec2-${var.name}"
  }
}
