variable "name" {
  type = string
}

variable "source_dir" {
  type = string
}

variable "output_path" {
  type = string
}

variable "s3_bucket_id" {
  type = string
}

variable "s3_key" {
  type = string
}

variable "compatible_runtimes" {
  type = list(string)
}
