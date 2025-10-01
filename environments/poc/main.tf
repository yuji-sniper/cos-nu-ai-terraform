# ==================================================
# VPC
# ==================================================
module "vpc" {
  source                           = "../../modules/vpc"
  project                          = local.project
  env                              = local.env
  region                           = local.region
  cidr_block                       = "10.1.0.0/16"
  public_subnet_availability_zones = local.availability_zones
}

# ==================================================
# Security Group
# ==================================================
module "security_group_ec2_comfyui" {
  source  = "../../modules/security_group"
  project = local.project
  env     = local.env
  name    = "ec2-comfyui"
  vpc_id  = module.vpc.vpc_id
}

module "security_group_rule_ec2_comfyui" {
  source            = "../../modules/security_group_rule"
  security_group_id = module.security_group_ec2_comfyui.security_group_id
  ingress_from_cidr_ipv4 = [
    {
      description = "request from internet"
      cidr_ipv4 = "0.0.0.0/0"
      from_port   = 8188
      to_port     = 8188
      ip_protocol = "tcp"
    },
    {
      description = "request from ssh"
      cidr_ipv4 = "0.0.0.0/0"
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
    }
  ]
}

# ==================================================
# EC2
# ==================================================
module "ec2_comfyui" {
  source  = "../../modules/ec2"
  project = local.project
  env     = local.env
  name    = "comfyui"
  ami                         = "ami-0365bff494b18bf93"
  instance_type               = "g4dn.xlarge"
  subnet_id                   = module.vpc.public_subnet_ids[0]
  security_group_ids          = [module.security_group_ec2_comfyui.security_group_id]
  associate_public_ip_address = true
  key_name                    = "${local.project}-${local.env}-comfyui"
  root_block_device = {
    volume_size           = 40
    volume_type           = "gp3"
    iops                  = 3000
    encrypted             = true
    delete_on_termination = false
  }
  # TODO: 手動で設置でもいいかもしれない
  # user_data = templatefile("files/ec2/user_data/comfyui/user_data.yaml.tftpl")
  # user_data_replace_on_change = true
}
