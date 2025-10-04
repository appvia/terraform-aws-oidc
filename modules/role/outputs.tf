output "read_only" {
  description = "The ARN of the IAM read-only role"
  value = {
    arn = aws_iam_role.ro.arn
  }
}

output "read_write" {
  description = "The ARN of the IAM read-write role"
  value = {
    arn = aws_iam_role.rw.arn
  }
}

output "state_reader" {
  description = "The ARN of the IAM state reader role"
  value = {
    arn = aws_iam_role.sr.arn
  }
}
