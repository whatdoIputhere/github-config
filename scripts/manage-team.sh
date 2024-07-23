#!/bin/bash
option="$1"
module_name="${2}_team"
team_name="$2"
team_description="$3"
repo_permissions="$4"
team_members="$5"
file_path="../resources/teams/teams_main.tf"

repo_permissions=$(echo $repo_permissions | tr '[:upper:]' '[:lower:]')
repo_permissions=${repo_permissions//write/push}
repo_permissions=${repo_permissions//read/pull}
module=$(sed -n "/module $module_name {/,/}/p" "$file_path")

echo "Module to be modified"
echo "$module"
echo ""

if [ "$option" == "Create team" ]; then
    if grep -q "module $module_name" "$file_path"; then
        echo "Module $module_name already exists in $file_path, no changes made"
        echo "If you want to update the team, please use the 'Update team' option"
        exit 0
    fi
    echo "Creating team"

    IFS=',' read -r -a input_member_array <<< "$team_members"
    
    quoted_members=$(printf '"%s",' "${input_member_array[@]}")    
    quoted_members="${quoted_members%,}"

    IFS=',' read -r -a input_repo_array <<< "$repo_name"
    
    quoted_repos=$(printf '"%s",' "${input_repo_array[@]}")    
    quoted_repos="${quoted_repos%,}"
    
    echo "
module $module_name {
    source = \"../../modules/gh_team\"
    team_name = \"$team_name\"
    team_description = \"$team_description\"
    team_members = [$quoted_members]
    team_repo_permissions = \"$repo_permissions\"
}" >> "$file_path"
    echo "Added module $module_name"
fi

if [ "$option" == "Delete team" ]; then
    if ! grep -q "module $module_name" "$file_path"; then
        echo "Module $module_name does not exist in $file_path, no changes made"        
        exit 0
    fi
    echo "Deleting team"

    sed -i -e "/^$/N;/\nmodule $module_name {/,/}/ d;" "$file_path"
    echo "Removed module $module_name"
fi

if [ "$option" == "Update team" ]; then 
    if ! grep -q "module $module_name" "$file_path"; then
        echo "Module $module_name does not exist in $file_path, no changes made"
        exit 0
    fi
    echo "Updating team"


    current_members=$(echo "$module" | grep "team_members =" | cut -d "=" -f 2 | tr -d '[:space:]')

    IFS=',' read -r -a input_member_array <<< "$team_members"

    new_members="["
    for member in "${input_member_array[@]}"; do
        if [ "$new_members" != "[" ]; then
            new_members+=","
        fi
        new_members+="\"$member\""
    done

    new_members+="]"

    escaped_current_members=$(printf '%s\n' "$current_members" | sed 's:[][\/.^$*]:\\&:g')
    escaped_new_members=$(printf '%s\n' "$new_members" | sed 's:[][\/.^$*]:\\&:g')

    IFS=',' read -r -a input_repo_array <<< "$repo_name"
    
    quoted_repos=$(printf '"%s",' "${input_repo_array[@]}")    
    quoted_repos="${quoted_repos%,}"
    
    sed -i -e "/^$/N;/\nmodule $module_name {/,/}/ s/$escaped_current_members/$escaped_new_members/" "$file_path"
    sed -i -e "/^$/N;/\nmodule $module_name {/,/}/ s/team_description = \".*\"/team_description = \"$team_description\"/" "$file_path"
    sed -i -e "/^$/N;/\nmodule $module_name {/,/}/ s/team_repo_permissions = \".*\"/team_repo_permissions = \"$repo_permissions\"/" "$file_path"    

    echo "Updated module $module_name"
fi

if [ "$option" == "Add member" ]; then
    current_members=$(echo "$module" | grep "team_members =" | cut -d "=" -f 2 | tr -d '[:space:]')

    IFS=',' read -r -a input_member_array <<< "$team_members"

    if [ "$current_members" == "[]" ]; then
        new_members="["
    else
        new_members="${current_members%]}"
    fi

    non_members=()
    for member in "${input_member_array[@]}"; do
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
    echo "Adding member(s)"
    sed -i -e "/^$/N;/\nmodule $module_name {/,/}/ s/$escaped_current_members/$escaped_new_members/" "$file_path"
    echo "Added the following member(s) to module $module_name"
    echo "${non_members[@]}"
fi


if [ "$option" == "Remove member" ]; then
    echo "Removing member(s)"

    current_members=$(echo "$module" | grep "team_members =" | cut -d "=" -f 2 | tr -d '[:space:]')

    IFS=',' read -r -a input_member_array <<< "$team_members"

    if [ "$current_members" == "[]" ]; then
        new_members="["
    else
        new_members="${current_members%]}"
    fi

    for member in "${input_member_array[@]}"; do
        new_members=$(echo "$new_members" | sed "s/\"$member\",//")
        new_members=$(echo "$new_members" | sed "s/\"$member\"//")
    done

    new_members=$(echo "$new_members" | sed 's/,\+$//')
    new_members+="]"

    escaped_current_members=$(printf '%s\n' "$current_members" | sed 's:[][\/.^$*]:\\&:g')
    escaped_new_members=$(printf '%s\n' "$new_members" | sed 's:[][\/.^$*]:\\&:g')

    sed -i -e "/^$/N;/\nmodule $module_name {/,/}/ s/$escaped_current_members/$escaped_new_members/" "$file_path"
    
    echo "Removed the following member(s) from module $module_name"
    echo "${input_member_array[@]}"
fi

if [ "$option" == "Add repository permissions" ]; then
    current_repos=$(echo "$module" | grep "team_repo_permissions =" | cut -d "=" -f 2 | tr -d '[:space:]' | tr -d '"')
    new_repos+="${current_repos%]}"

    IFS=',' read -r -a input_repo_array <<< "$repo_permissions"
    non_repos=""

    for repo in "${input_repo_array[@]}"; do
        if [[ "$current_repos" == *"$repo"* ]]; then
            echo "Repository permission $repo already assigned to team $module_name"
        elif [ -z "$new_repos" ]; then
            new_repos+="$repo"
            non_repos+="$repo "
        else    
            new_repos+=",$repo"
            non_repos+="$repo "
        fi
    done

    echo ""
    if [ -z "$non_repos" ]; then
        echo "No new repository permissions were added to module $module_name"
        exit 0
    fi

    sed -i -e "/^$/N;/\nmodule $module_name {/,/}/ s/team_repo_permissions = \".*\"/team_repo_permissions = \"$new_repos\"/" "$file_path"
    echo "Added the following repository permissions to module $module_name"
    echo "$non_repos"
fi

if [ "$option" == "Remove repository permissions" ]; then
    current_repos=$(echo "$module" | grep "team_repo_permissions =" | cut -d "=" -f 2 | tr -d '[:space:]' | tr -d '"')
    
    IFS=',' read -r -a permissions_array <<< "$repo_permissions"
    removed_permissions=""
    not_found_permissions=""
    
    for permission in "${permissions_array[@]}"; do
        if [[ "$current_repos" == *"$permission"* ]]; then
            current_repos=$(echo "$current_repos" | sed "s/$permission//")
            removed_permissions+="$permission,"
        else            
            not_found_permissions+="$permission,"
        fi
    done
    
    current_repos=$(echo "$current_repos" | sed 's/,,/,/g' | sed 's/,$//g' | sed 's/^,//g')
    
    escaped_current_repos=$(printf '%s\n' "$current_repos" | sed 's:[][\/.^$*]:\\&:g')
    sed -i -e "/^$/N;/\nmodule $module_name {/,/}/ s/team_repo_permissions =.*/team_repo_permissions = \"$current_repos\"/" "$file_path"
        
    if [ -n "$removed_permissions" ]; then
        echo "Removed the following repository permissions from module $module_name"
        echo "${removed_permissions%,}"
        echo ""
    fi
    if [ -n "$not_found_permissions" ]; then
        echo "The following permissions weren't found in module $module_name so they couldn't be removed"
        echo "${not_found_permissions%,}"
        echo ""
    fi
fi


module=$(sed -n "/module $module_name {/,/}/p" "$file_path")
echo "Module after changes"
echo "$module"