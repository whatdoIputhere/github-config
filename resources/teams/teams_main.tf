provider "github" {
  owner = "pecarmoorg"
}

module api_team {
    source = "../../modules/gh_team"
    team_name = "api"
    team_description = "api team"
    team_members = ["api"] 
    repo_name = "whatdoIputhereTEST"
}
