output "read_only" {
  value = {
    arn = aws_iam_role.ro.arn
  }
}

output "read_write" {
  value = {
    arn = aws_iam_role.rw.arn
  }
}
