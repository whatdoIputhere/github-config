locals {
  repo_permission_map = {
    for pair in split(",", var.team_repo_permissions) :
    element(split(":", pair), 0) => element(split(":", pair), 1)
  }
}

resource "github_team" "team" {
  name        = var.team_name
  description = var.team_description
  privacy     = "closed"
}

resource "github_team_members" "team_members" {
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

resource "github_team_repository" "team_repo" {
  for_each   = local.repo_permission_map
  team_id    = github_team.api_team.id
  repository = each.key
  permission = each.value
}