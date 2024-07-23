variable "team_name" {
  type = string
}

variable "team_description" {
  type = string
}

variable "team_members" {
  type = list(string)
}

variable "repo_name" {
  type = string
}

variable "repo_permission" {
  type = string
  default = "pull"
}