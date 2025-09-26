module "s3_comfyui" {
  source = "../../modules/s3"
  project = local.project
  env = local.env
  name = "comfyui"
}
