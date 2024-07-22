#!/bin/bash

option="$1"
module_name="${2}_team"
team_name="$2"
team_description="$3"
team_members="$4"
repo_name="$5"
file_path="../resources/teams/teams_main.tf"

git config --global user.email "pedromgc21@gmail.com"
git config --global user.name "whatdoIputhere"
export github_token="$GH_TOKEN"
gh auth status


if [ "$option" == "Create team" ]; then
    echo "Creating team"
    if grep -q "module $module_name" "$file_path"; then
        echo "Module $module_name already exists in $file_path, no changes made"
        exit 0
    fi

    IFS=',' read -r -a member_array <<< "$team_members"
    
    quoted_members=$(printf '"%s",' "${member_array[@]}")    
    quoted_members="${quoted_members%,}"
    
    echo "
module $module_name {
    source = \"../../modules/gh_team\"
    team_name = \"$team_name\"
    team_description = \"$team_description\"
    team_members = [$quoted_members] 
    repo_name = \"$repo_name\"
}" >> "$file_path"
    echo "Added module $module_name"

    git add .
    git commit -m "Add module $module_name"
fi

if [ "$option" == "Delete team" ]; then 
    if ! grep -q "module $module_name" "$file_path"; then
        echo "Module $module_name does not exist in $file_path, no changes made"
        exit 0
    fi

    sed -i -e "/^$/N;/\nmodule $module_name {/,/}/ d;" "$file_path"
    echo "Removed module $module_name"

    git add .
    git commit -m "Remove module $module_name"
fi


if [ "$option" == "Add member" ]; then
    module=$(sed -n "/module $module_name {/,/}/p" "$file_path")

    current_members=$(echo "$module" | grep "team_members =" | cut -d "=" -f 2 | tr -d '[:space:]')

    IFS=',' read -r -a member_array <<< "$team_members"

    if [ "$current_members" == "[]" ]; then
        new_members="["
    else
        new_members="${current_members%]}"
    fi

    non_members=()
    for member in "${member_array[@]}"; do
        if [[ "$current_members" == *"$member"* ]]; then
            echo "User $member already belongs to team $module_name"
        else
            non_members+=("$member")
        fi
    done
    
    for member in "${non_members[@]}"; do
        if [ "$new_members" != "[" ]; then
            new_members+=","
        fi
        new_members+="\"$member\""
    done

    new_members+="]"

    escaped_current_members=$(printf '%s\n' "$current_members" | sed 's:[][\/.^$*]:\\&:g')
    escaped_new_members=$(printf '%s\n' "$new_members" | sed 's:[][\/.^$*]:\\&:g')
    
    if [ ${#non_members[@]} -eq 0 ]; then
        echo "No new member was added to module $module_name"
        exit 0
    fi
    sed -i -e "/^$/N;/\nmodule $module_name {/,/}/ s/$escaped_current_members/$escaped_new_members/" "$file_path"
    echo "Added the following member(s) to module $module_name"
    echo "${non_members[@]}"

    git add .
    git commit -m "Add member(s) to module $module_name"
fi


if [ "$option" == "Remove member" ]; then
    module=$(sed -n "/module $module_name {/,/}/p" "$file_path")

    current_members=$(echo "$module" | grep "team_members =" | cut -d "=" -f 2 | tr -d '[:space:]')

    IFS=',' read -r -a member_array <<< "$team_members"

    if [ "$current_members" == "[]" ]; then
        new_members="["
    else
        new_members="${current_members%]}"
    fi

    for member in "${member_array[@]}"; do
        new_members=$(echo "$new_members" | sed "s/\"$member\",//")
        new_members=$(echo "$new_members" | sed "s/\"$member\"//")
    done

    new_members=$(echo "$new_members" | sed 's/,\+$//')
    new_members+="]"

    escaped_current_members=$(printf '%s\n' "$current_members" | sed 's:[][\/.^$*]:\\&:g')
    escaped_new_members=$(printf '%s\n' "$new_members" | sed 's:[][\/.^$*]:\\&:g')

    sed -i -e "/^$/N;/\nmodule $module_name {/,/}/ s/$escaped_current_members/$escaped_new_members/" "$file_path"
    
    echo "Removed the following member(s) from module $module_name"
    echo "${member_array[@]}"

    git add .
    git commit -m "Remove member(s) from module $module_name"
fi

git push origin main