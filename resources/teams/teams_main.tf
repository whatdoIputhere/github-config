provider "github" {
  owner = "pecarmoorg"
}

module "team_api" {
    source = "../../modules/gh_team"
    team_name = "api"
    team_description = "this is the api team"
    team_members = ["whatdoIputhereTEST"]
    team_repo_permissions = "api:push,updated-test-repo:pull"
}
