module "repo_api" {
    source = "./modules/gh_repo"
    repo_name = "api"
}

module "repo_app2" {
    source = "./modules/gh_repo"
    repo_name = "app2"
}

module "repo_frontend" {
    source = "./modules/gh_repo"
    repo_name = "frontend"
}

module "repo_infra" {
    source = "./modules/gh_repo"
    repo_name = "infra"
}