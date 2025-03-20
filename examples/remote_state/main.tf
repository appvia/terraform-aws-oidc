module "basic" {
  source = "../../modules/remote_state"

  // ID of the destination AWS account from which remote
  // state is to be read from.
  account_id = "0123456789"

  // Name of the region of the destination AWS account where
  // resource have been deployed to.
  region = "eu-west-2"

  // The path of the repository which produced the remote
  // state being read.
  repository = "appvia/repo-1"

  // Path to the identity token file containing the credentials needed
  // to assume the role.
  web_identity_token_file = "/tmp/web_identity_token_file"
}
