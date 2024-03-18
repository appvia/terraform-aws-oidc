provider "aws" {

}

run "github_providers" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name            = "common"
    description     = "Test role using GitHub OIDC provider"
    repository      = "appvia/something"
    common_provider = "github"

    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

    read_only_policy_arns = [
      "arn:aws:iam::aws:policy/ReadOnlyAccess",
    ]

    read_write_policy_arns = [
      "arn:aws:iam::aws:policy/AdministratorAccess",
    ]
  }
}

run "gitlab_providers" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name            = "common"
    description     = "Test role using GitLab OIDC provider"
    repository      = "appvia/something"
    common_provider = "gitlab"

    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

    read_only_policy_arns = [
      "arn:aws:iam::aws:policy/ReadOnlyAccess",
    ]

    read_write_policy_arns = [
      "arn:aws:iam::aws:policy/AdministratorAccess",
    ]
  }
}

run "custom_providers" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name        = "custom"
    description = "Test role using custom OIDC provider"
    repository  = "appvia/something"

    custom_provider = {
      url                    = "https://token.actions.githubusercontent.com"
      audiences              = ["test"]
      subject_branch_mapping = "repo={repo},branch={ref}"
      subject_tag_mapping    = "repo={repo},tag={ref}"
    }

    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

    read_only_inline_policies = {
      ReadOnly = jsonencode({
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Sid" : "ReadOnlyActions",
            "Effect" : "Allow",
            "Action" : [
              "ec2:Describe*",
              "ec2:Get*",
              "ec2:ListImagesInRecycleBin",
              "ec2:ListSnapshotsInRecycleBin",
              "ec2:SearchLocalGatewayRoutes",
              "ec2:SearchTransitGatewayRoutes",
              "s3:DescribeJob",
              "s3:Get*",
              "s3:List*",
            ],
            "Resource" : "*"
          }
        ]
      })
    }

    read_write_inline_policies = {
      AdministratorAccess = jsonencode({
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Effect" : "Allow",
            "Action" : "*",
            "Resource" : "*"
          }
        ]
      })
    }
  }
}
