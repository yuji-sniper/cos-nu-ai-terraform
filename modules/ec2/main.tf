# IAMロール
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_comfyui" {
  name               = "${var.project}-${var.env}-ec2-comfyui"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ec2_comfyui_ssm_core" {
  role       = aws_iam_role.ec2_comfyui.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "ec2_comfyui_s3_private_put" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.s3_private_bucket_id}/*"]
  }
}

resource "aws_iam_policy" "ec2_comfyui_s3_private_put" {
  name   = "${var.project}-${var.env}-ec2-comfyui-s3-private-put"
  policy = data.aws_iam_policy_document.ec2_comfyui_s3_private_put.json
}

resource "aws_iam_role_policy_attachment" "ec2_comfyui_s3_private_put" {
  role       = aws_iam_role.ec2_comfyui.name
  policy_arn = aws_iam_policy.ec2_comfyui_s3_private_put.arn
}

resource "aws_iam_instance_profile" "comfyui" {
  name = "${var.project}-${var.env}-comfyui"
  role = aws_iam_role.ec2_comfyui.name
}

# EC2インスタンス
resource "aws_instance" "comfyui" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = var.comfyui_security_group_ids
  iam_instance_profile        = aws_iam_instance_profile.comfyui.name
  associate_public_ip_address = false

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    device_name           = "/dev/sda1"
    volume_size           = var.ebs_volume_size
    volume_type           = "gp3"
    iops                  = 3000
    encrypted             = true
    delete_on_termination = false
  }
}
