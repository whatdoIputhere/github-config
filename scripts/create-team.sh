module_name="\"${1}_team\""
team_name="\"$1\""
team_description="\"$2\""
team_members="\"$3\""
repo_name="\"$4\""


echo "
module $module_name {
    source = \"../../modules/gh_team\"
    team_name = $team_name
    team_description = $team_description
    team_members = [
        $team_members
    ]
    repo_name = $repo_name
}"