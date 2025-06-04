mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
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
    tags = {
      Name = "GitHub"
    }

    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

    read_only_policy_arns = [
      "arn:aws:iam::aws:policy/ReadOnlyAccess",
    ]

    read_write_policy_arns = [
      "arn:aws:iam::aws:policy/AdministratorAccess",
    ]

    shared_repositories = [
      "appvia/repo-1",
      "appvia/repo-2",
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

    tags = {
      Name = "GitLab"
    }

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
    name            = "custom"
    description     = "Test role using custom OIDC provider"
    repository      = "appvia/something"
    common_provider = ""

    custom_provider = {
      url                    = "https://token.actions.githubusercontent.com"
      audiences              = ["test"]
      subject_branch_mapping = "repo={repo},branch={ref}"
      subject_tag_mapping    = "repo={repo},tag={ref}"
      subject_reader_mapping = "repo={repo}"
      subject_env_mapping    = "repo={repo},environment={environment}"
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

    tags = {
      Name = "Custom"
    }
  }
}
