output "lambda_comfyui_bff_security_group_id" {
  value = aws_security_group.lambda_comfyui_bff.id
}

output "ec2_comfyui_security_group_id" {
  value = aws_security_group.ec2_comfyui.id
}
