data "archive_file" "this" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = var.output_path
}

resource "aws_s3_object" "this" {
  bucket = var.s3_bucket_id
  key    = var.s3_key
  source = data.archive_file.this.output_path
  etag   = filemd5(data.archive_file.this.output_path)
}

resource "aws_lambda_layer_version" "this" {
  layer_name = var.name
  s3_bucket  = aws_s3_object.this.bucket
  s3_key     = aws_s3_object.this.key
  source_code_hash = filebase64sha256(data.archive_file.this.output_path)
  compatible_runtimes = var.compatible_runtimes
}
