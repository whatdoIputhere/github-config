resource "github_team" "api_team" {
  name        = var.team_name
  description = var.team_description
  privacy     = "closed"

}

resource "github_team_members" "api_team_members" {
    team_id = github_team.api_team.id

    members {
        username = "whatdoIputhere"
        role     = "maintainer"
    }

    dynamic "members" {
        for_each = var.team_members
        content {
            username = members.value
            role     = "member"
        }
    }
}

resource "github_team_repository" "api_team_repo" {
  team_id    = github_team.api_team.id
  repository = var.repo_name
  permission = var.repo_permission
}