module "network" {
  source             = "../../modules/network"
  project            = local.project
  env                = local.env
  region             = local.region
  availability_zones = local.availability_zones
}

module "security_group" {
  source  = "../../modules/security_group"
  project = local.project
  env     = local.env
  vpc_id  = module.network.vpc_id
}

module "secretmanager" {
  source  = "../../modules/secret_manager"
  project = local.project
  env     = local.env
}

module "s3" {
  source  = "../../modules/s3"
  project = local.project
  env     = local.env
}

module "cloudfront" {
  source                 = "../../modules/cloudfront"
  project                = local.project
  env                    = local.env
  root_domain            = local.root_domain
  cdn_public_key         = var.cdn_public_key
  cdn_bucket_id          = module.s3.private_bucket_id
  cdn_bucket_domain_name = module.s3.private_bucket_domain_name
}

module "route53" {
  source                                  = "../../modules/route53"
  root_domain                             = local.root_domain
  vercel_cname_target                     = var.vercel_cname_target
  cloudfront_cdn_distribution_domain_name = module.cloudfront.cdn_distribution_domain_name
}

module "ec2" {
  source                     = "../../modules/ec2"
  project                    = local.project
  env                        = local.env
  s3_private_bucket_id       = module.s3.private_bucket_id
  # Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.7 (Ubuntu 22.04) 20250907
  ami                        = "ami-0365bff494b18bf93"
  instance_type              = "g4dn.xlarge"
  private_subnet_id          = module.network.private_subnet_ids[0]
  comfyui_security_group_ids = [module.security_group.ec2_comfyui_security_group_id]
  ebs_volume_size            = 50
}

module "dynamodb" {
  source  = "../../modules/dynamodb"
  project = local.project
  env     = local.env
}

module "lambda" {
  source  = "../../modules/lambda"
  project = local.project
  env     = local.env
  region  = local.region
  root_domain = local.root_domain
  comfyui_instance_id = module.ec2.comfyui_instance_id
  private_subnet_ids = module.network.private_subnet_ids
  security_group_ids = [module.security_group.ec2_comfyui_security_group_id]
  status_dynamo_db_table_name = module.dynamodb.comfyui_instance_table_name
  idle_timeout_minutes = 20
  comfyui_bff = {
    source_dir = "files/lambda/functions/comfyui_bff"
    output_path = "files/lambda/functions/comfyui_bff/lambda_function.zip"
  }
  stop_comfyui = {
    source_dir = "files/lambda/functions/stop_comfyui"
    output_path = "files/lambda/functions/stop_comfyui/lambda_function.zip"
  }
}

module "scheduler_stop_comfyui" {
  source  = "../../modules/scheduler"
  project = local.project
  env     = local.env
  name = "stop_comfyui"
  target_arn = module.lambda.stop_comfyui_lambda_function_arn
  schedule_expression = "cron(0/5 * * * ? *)"
}
