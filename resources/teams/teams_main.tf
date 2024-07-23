provider "github" {
  owner = "pecarmoorg"
}

module api_team {
    source = "../../modules/gh_team"
    team_name = "api"
    team_description = "this is the api team"
    team_members = ["whatdoIputhereTEST"]
    team_repo_permissions = "api:push,frontend:pull"
}
 