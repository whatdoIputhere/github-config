variable "team_name" {
  type = string
}

variable "team_description" {
  type = string
}

variable "team_members" {
  type = list(string)
}

variable "team_repo_permissions" {
  type = string
}