provider "github" {
  owner = "pecarmoorg"
  
}

resource "github_membership" "admin" {
  username = "whatdoIputhere"
  role = "admin"
}

resource "github_membership" "member2" {
  username = "whatdoIputhereTEST"
  role = "member"
}