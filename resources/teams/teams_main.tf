module "api_team" {
    source = "../../modules/gh_team"
    team_name = "api"
    team_description = "API team"
    team_members = [
        "whatdoIputhereTEST",
    ]
    repo_name = "api"
}