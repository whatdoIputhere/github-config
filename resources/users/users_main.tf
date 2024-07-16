provider "github" {
  owner = "pecarmoorg"
}

resource "github_membership" "admin" {
  username = "whatdoIputhere"
  role = "admin"
}

resource "github_membership" "whatdoIputhereTEST" {
  username = "whatdoIputhereTEST"
  role = "member"
}