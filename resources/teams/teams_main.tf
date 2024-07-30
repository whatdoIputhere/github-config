provider "github" {
  owner = "pecarmoorg"
}

module "team_api" {
 
module api_team {
    source = "../../modules/gh_team"
    team_name = "api"
    team_description = "api team desc"
    team_members = ["whatdoIputhereTEST"]
    team_repo_permissions = "api:push,updated-test-repo:pull"
    team_repo_permissions = "api:push,frontend:pull"
}
