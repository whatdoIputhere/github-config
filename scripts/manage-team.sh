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