#!/bin/bash

file_path="../resources/repositories/repos_main.tf"
repo_id_mapping_path="../resources/repositories/repo_id_mapping.json"

echo_module() {
    module=$(sed -n "/module \"$1\" {/,/}/p" "$file_path")
    echo "$module"
}

get_module_id() {
    module_id=$(jq -r --arg repo_name "$1" '.[] | select(.repo_name == $repo_name) | .module_id' "$repo_id_mapping_path")
    echo "$module_id"
}

option="$1"
repo_name="$(echo "$2" | cut -d">" -f1)"
new_repo_name="$(echo "$2" | cut -d">" -f2)"
repo_description="$3"
repo_application_type="$4"

if [ "$repo_application_type" == "None" ]; then
    repo_application_type=""
fi

module_id=$(get_module_id "$repo_name")
module=$(sed -n "/module \"repo_$module_id\" {/,/}/p" "$file_path")

if [ "$option" == "Create repository" ]; then
    if [ -n "$module_id" ]; then
        echo "Repository with name $repo_name already exists in $file_path, no changes were made"
        echo "If you wish to update the repository, please use the 'Update repository' option"
        exit 1
    fi

    module_id="repo_$(uuidgen)"
    echo "Adding repository module to $file_path"

    echo "
module \"$module_id\" {
    source = \"../../modules/gh_repo\"
    repo_name = \"$repo_name\"
    repo_description = \"$repo_description\"
    repo_application_type = \"$repo_application_type\"
}" >> "$file_path"

    if [ ! -s "$repo_id_mapping_path" ]; then
        echo "[]" > "$repo_id_mapping_path"
    fi

    tmp_file=$(mktemp)
    jq --arg repo_name "$repo_name" --arg module_id "$module_id" '. += [{"repo_name": $repo_name, "module_id": $module_id}]' "$repo_id_mapping_path" > "$tmp_file"
    
    if [ $? -ne 0 ]; then
        echo "Error: jq command failed"
        rm "$tmp_file"
        exit 1
    fi

    mv "$tmp_file" "$repo_id_mapping_path"

    echo "" 
    echo "Added module:"
    echo_module "$module_id"
    exit 0
fi

if [ "$option" == "Delete repository" ]; then
    if [ -z "$module_id" ]; then
        echo "Repository with name $repo_name does not exist in $file_path, no changes were made"
        echo "If you wish to create the repository, please use the 'Create repository' option"
        exit 1
    fi

    echo "Deleting repository module from $file_path"

    sed -i -e "/^$/N;/\nmodule \"$module_id\" {/,/}/ d;" "$file_path"
    echo "" 
    echo "Removed module:"
    echo "$module"

    tmp_file=$(mktemp)
    jq --arg repo_name "$repo_name" 'del(.[].repo_name | select(. == $repo_name)) | map(select(.repo_name != null))' "$repo_id_mapping_path" > "$tmp_file"

    if [ $? -ne 0 ]; then
        echo "Error: jq command failed"
        rm "$tmp_file"
        exit 1
    fi

    mv "$tmp_file" "$repo_id_mapping_path"

    teams_file="../resources/teams/teams_main.tf"
    sed -i -e "/team_repo_permissions/s/\b$repo_name:[^,]*,//g" "$teams_file"
    sed -i -e "/team_repo_permissions/s/,$repo_name:[^,]*\b//g" "$teams_file"
    sed -i -e "/team_repo_permissions/s/\b$repo_name:[^,]*//g" "$teams_file"

    exit 0
fi

if [ "$option" == "Update repository" ]; then
    if [ -z "$module_id" ]; then
        echo "Repository with name $repo_name does not exist in $file_path, no changes were made"
        echo "If you wish to create the repository, please use the 'Create repository' option"
        exit 1
    fi

    echo "" 
    echo "Updating repository module $module_id"

    if [ "$repo_name" != "$new_repo_name" ]; then
        sed -i -e "/module \"$module_id\" {/,/}/ s/repo_name = \".*\"/repo_name = \"$new_repo_name\"/" "$file_path"
        sed -i -e "/\"repo_name\": \"$repo_name\"/ s/\"repo_name\": \".*\"/\"repo_name\": \"$new_repo_name\"/" "$repo_id_mapping_path"
        teams_file="../resources/teams/teams_main.tf"
        sed -i -e "/module \"team_.*\" {/,/}/ s/$repo_name/$new_repo_name/g" "$teams_file"
    fi
    
    if [ -n "$repo_description" ]; then
        sed -i -e "/module \"$module_id\" {/,/}/ s/repo_description = \".*\"/repo_description = \"$repo_description\"/" "$file_path"
    fi

    if [ -n "$repo_application_type" ]; then
        sed -i -e "/module \"$module_id\" {/,/}/ s/repo_application_type = \".*\"/repo_application_type = \"$repo_application_type\"/" "$file_path"
    fi

    echo "" 
    echo "Updated module:"
    echo_module "$module_id"
    exit 0
fi