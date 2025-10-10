resource "aws_iam_user" "this" {
  name = "${var.project}-${var.env}-${var.name}"
}

# Managed Policy
resource "aws_iam_user_policy_attachment" "managed" {
  count = length(var.managed_policy_arns)
  user = aws_iam_user.this.name
  policy_arn = var.managed_policy_arns[count.index]
}

# Inline Policy
resource "aws_iam_policy" "inline" {
  count = var.inline_policy_json_document != null ? 1 : 0
  name = "${var.project}-${var.env}-${var.name}"
  policy = var.inline_policy_json_document
}

resource "aws_iam_user_policy_attachment" "inline" {
  count = var.inline_policy_json_document != null ? 1 : 0
  user = aws_iam_user.this.name
  policy_arn = aws_iam_policy.inline[0].arn
}
