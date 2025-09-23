# ==============================
# Lambda(ComfyUI BFF)
# ==============================
resource "aws_security_group" "lambda_comfyui_bff" {
  name   = "${var.project}-${var.env}-lambda-comfyui-bff"
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "lambda_comfyui_bff" {
  security_group_id = aws_security_group.lambda_comfyui_bff.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  to_port     = 0
  ip_protocol = "-1"
}

# ==============================
# EC2 ComfyUI
# ==============================
resource "aws_security_group" "ec2_comfyui" {
  name   = "${var.project}-${var.env}-ec2-comfyui"
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "ec2_comfyui" {
  security_group_id = aws_security_group.ec2_comfyui.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  to_port     = 0
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "ec2_comfyui_from_lambda_api" {
  security_group_id = aws_security_group.ec2_comfyui.id

  referenced_security_group_id = aws_security_group.lambda_api.id
  from_port                    = 8188
  to_port                      = 8188
  ip_protocol                  = "tcp"
}
