provider "github" {
  owner = "pecarmoorg"
}

module "team_api team" {
    source = "../../modules/gh_team"
    team_name = "api team"
    team_description = "api team"
    team_members = ["whatdoIputhereTEST"]
    team_repo_permissions = "api:push,frontend:pull"
}
