provider "github" {
  owner = "pecarmoorg"
}

module "team_e08e3315-fc0c-4a1f-941e-41c526199ba6" {
    source = "../../modules/gh_team"
    team_name = "api team"
    team_description = "this is the api team"
    team_members = ["whatdoIputhereTEST"]
    team_repo_permissions = "api:push"
}
