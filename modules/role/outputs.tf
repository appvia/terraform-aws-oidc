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

output "state_reader" {
  value = {
    arn = aws_iam_role.sr.arn
  }
}
