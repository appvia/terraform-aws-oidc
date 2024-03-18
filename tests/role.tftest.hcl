provider "aws" {

}

run "github_providers" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name            = "common"
    common_provider = "github"

    repositories = [
      "appvia/something",
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
    repository      = "appvia/something"
    common_provider = "gitlab"
  }
}

run "custom_providers" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name       = "custom"
    repository = "appvia/something"

    custom_provider = {
      url                    = "https://token.actions.githubusercontent.com"
      audiences              = ["test"]
      subject_branch_mapping = "repo={repo},branch={ref}"
      subject_tag_mapping    = "repo={repo},tag={ref}"
    }
  }
}
