#!/bin/bash
file_path="../resources/teams/teams_main.tf"
team_id_mapping_path="../resources/teams/team_id_mapping.json"
echo_module() {
    module=$(sed -n "/module \"$1\" {/,/}/p" "$file_path")
    echo "$module"
}
get_module_id() {
    module_id=$(jq -r --arg team_name "$1" '.[] | select(.team_name == $team_name) | .module_id' "$team_id_mapping_path")
    echo "$module_id"
}
option="$1"
team_name="$(echo "$2" | cut -d">" -f1)"
new_team_name="$(echo "$2" | cut -d">" -f2)"
team_description="$3"
repo_permissions="$4"
team_members="$5"
repo_permissions=$(echo $repo_permissions | tr '[:upper:]' '[:lower:]')
repo_permissions=${repo_permissions//write/push}
repo_permissions=${repo_permissions//read/pull}
module_id=$(get_module_id "$team_name")
module=$(sed -n "/module \"$module_id\" {/,/}/p" "$file_path")

if [ "$option" == "Create team" ]; then

    if [ -n "$module_id" ]; then
        echo "Team with name $team_name already exists in $file_path, no changes were made"
        echo "If you wish to update the team, please use the 'Update team' option"
        exit 1
    fi

    module_id="team_$(uuidgen)"
    echo "Creating team"
    IFS=',' read -r -a input_member_array <<< "$team_members"
    
    quoted_members=$(printf '"%s",' "${input_member_array[@]}")
    quoted_members="${quoted_members%,}"
    
    echo "
module \"$module_id\" {
    source = \"../../modules/gh_team\"
    team_name = \"$team_name\"
    team_description = \"$team_description\"
    team_members = [$quoted_members]
    team_repo_permissions = \"$repo_permissions\"
}" >> "$file_path"
    
    if [ ! -s "$team_id_mapping_path" ]; then
        echo "[]" > "$team_id_mapping_path"
    fi
    tmp_file=$(mktemp)
    jq --arg team_name "$team_name" --arg module_id "$module_id" '. += [{"team_name": $team_name, "module_id": $module_id}]' "$team_id_mapping_path" > "$tmp_file"
    if [ $? -ne 0 ]; then
        echo "Error: jq command failed"
        rm "$tmp_file"
        exit 1
    fi
    mv "$tmp_file" "$team_id_mapping_path"
    
    echo "Added module:"
    echo_module "$module_id"
    exit 0
fi

if [ "$option" == "Delete team" ]; then
    if [ -z "$module_id" ]; then
        echo "Team with name $team_name does not exist in $file_path, no changes were made"
        exit 1
    fi
    echo "Deleting team"
    sed -i -e "/^$/N;/\nmodule \"$module_id\" {/,/}/ d;" "$file_path"
    echo "Removed module:"
    echo "$module"
    
    tmp_file=$(mktemp)
    jq --arg team_name "$team_name" 'del(.[].team_name | select(. == $team_name)) | map(select(.team_name != null))' "$team_id_mapping_path" > "$tmp_file"
    if [ $? -ne 0 ]; then
        echo "Error: jq command failed"
        rm "$tmp_file"
        exit 1
    fi
    mv "$tmp_file" "$team_id_mapping_path"
    
    exit 0
fi

if [ "$option" == "Update team" ]; then
    if [ -z "$module_id" ]; then
        echo "Team with name $team_name does not exist in $file_path, no changes were made"
        exit 1
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

    sed -i -e "/^$/N;/\nmodule \"$module_id\" {/,/}/ s/team_name = \".*\"/team_name = \"$new_team_name\"/" "$file_path"
    sed -i -e "/^$/N;/\nmodule \"$module_id\" {/,/}/ s/repo_permissions = \".*\"/repo_permissions = \"$repo_permissions\"/" "$file_path"
    sed -i -e "/^$/N;/\nmodule \"$module_id\" {/,/}/ s/$escaped_current_members/$escaped_new_members/" "$file_path"
    sed -i -e "/^$/N;/\nmodule \"$module_id\" {/,/}/ s/team_description = \".*\"/team_description = \"$team_description\"/" "$file_path"
    
    if [ "$team_name" != "$new_team_name" ]; then
        sed -i -e "/module \"$module_id\" {/,/}/ s/team_name = \".*\"/team_name = \"$new_team_name\"/" "$file_path"
        sed -i -e "/\"team_name\": \"$team_name\"/ s/\"team_name\": \".*\"/\"team_name\": \"$new_team_name\"/" "$team_id_mapping_path"
    fi
    
    echo "Updated module:"
    echo_module "$module_id"
    exit 0
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
            echo "User $member already belongs to team $team_name"
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
        echo "No new member was added to team \"$team_name\""
        exit 0
    fi
    echo "Adding member(s)"    
    sed -i -e "/^$/N;/\nmodule \"$module_id\" {/,/}/ s/$escaped_current_members/$escaped_new_members/" "$file_path"
    echo "Added the following member(s) to team \"$team_name\""
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

    sed -i -e "/^$/N;/\nmodule \"$module_id\" {/,/}/ s/$escaped_current_members/$escaped_new_members/" "$file_path"

    echo "Removed the following member(s) from team \"$team_name\""
    echo "${input_member_array[@]}"
fi

if [ "$option" == "Add repository permissions" ]; then
    current_repos=$(echo "$module" | grep "team_repo_permissions =" | cut -d "=" -f 2 | tr -d '[:space:]' | tr -d '"')
    new_repos+="${current_repos%]}"

    IFS=',' read -r -a input_repo_array <<< "$repo_permissions"
    non_repos=""

    for repo in "${input_repo_array[@]}"; do
        if [[ "$current_repos" == *"$repo"* ]]; then
            echo "Repository permission $repo already assigned to team $team_name"
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
        echo "No new repository permissions were added to team \"$team_name\""
        exit 0
    fi
    echo "$module_id"
    sed -i -e "/^$/N;/\nmodule \"$module_id\" {/,/}/ s/team_repo_permissions = \".*\"/team_repo_permissions = \"$new_repos\"/" "$file_path"
    echo "Added the following repository permissions to team \"$team_name\""
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
    sed -i -e "/^$/N;/\nmodule \"$module_id\" {/,/}/ s/team_repo_permissions =.*/team_repo_permissions = \"$current_repos\"/" "$file_path"

    if [ -n "$removed_permissions" ]; then
        echo "Removed the following repository permissions from team \"$team_name\""
        echo "${removed_permissions%,}"        
    fi
    if [ -n "$not_found_permissions" ]; then
        echo "The following permissions weren't found in team \"$team_name\" so they couldn't be removed"
        echo "${not_found_permissions%,}"        
    fi
fi

module=$(sed -n "/module \"$module_id\" {/,/}/p" "$file_path")
echo ""
echo "Module after changes"
echo "$module"