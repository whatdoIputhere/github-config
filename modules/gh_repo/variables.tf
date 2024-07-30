variable "repo_name" {}

variable "repo_visibility" {
  type = string
  default = "private"
}

variable "repo_application_type" {
  type = string
}

variable "repo_description" {
  type = string
}