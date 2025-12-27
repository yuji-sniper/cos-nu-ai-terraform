resource "aws_ec2_instance_state" "stop" {
  instance_id = var.instance_id
  state       = "stopped" 
}

resource "time_static" "timestamp" {}

resource "aws_ami_from_instance" "this" {
  name = "${var.project}-${var.env}-${var.name}-${replace(time_static.timestamp.rfc3339, ":", "")}"
  source_instance_id = var.instance_id
  snapshot_without_reboot = true

  tags = {
    Name = "${var.project}-${var.env}-${var.name}-${replace(time_static.timestamp.rfc3339, ":", "")}"
  }

  depends_on = [
    aws_ec2_instance_state.stop
  ]
}
