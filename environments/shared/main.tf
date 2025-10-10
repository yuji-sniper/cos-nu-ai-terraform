# ==================================================
# SSM Parameter
# ==================================================
module "ssm_parameter_civitai_api_key" {
  source  = "../../modules/ssm_parameter"
  project = local.project
  env     = local.env
  name    = "civitai-api-key"
  type    = "String"
  value   = "dummy"
}
