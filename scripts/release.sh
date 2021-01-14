#!/bin/bash

set -e

PROJECT_PATH=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

release() {
    if [[ -z "$1" || -z "$2" ]] || [[ "$1" != 'task-runner' && $1 != 'create-task-runner' ]] || [[ "$2" != 'major' && $2 != 'minor' && $2 != 'patch' ]]; then
        printf -- 'Usage: release.sh task-runner|create-task-runner major|minor|patch \n' >&2
        exit 1
    fi

    local package_name=$1 version_bump=$2 current_major current_minor current_patch new_version

    if [[ -n $(git diff -- "$PROJECT_PATH/packages/$package_name/VERSION") ]]; then
        printf -- 'The VERSION file of the %s package has uncomitted changes,\nplease commit them or reset the changes and try again.\n' "$package_name" >&2
        exit 1
    fi
    if [[ -n $(git diff --staged) ]]; then
        printf -- 'There are staged changes in the git working copy, please unstage the changes and try again.\n' >&2
        exit 1
    fi

    current_major=$(grep -oP '^\K(\d+)' < "$PROJECT_PATH/packages/$package_name/VERSION")
    current_minor=$(grep -oP '^\d+\.\K(\d+)' < "$PROJECT_PATH/packages/$package_name/VERSION")
    current_patch=$(grep -oP '^\d+\.\d+\.\K(\d+)' < "$PROJECT_PATH/packages/$package_name/VERSION")

    case "$version_bump" in
        major) current_major=$((current_major + 1));;
        minor) current_minor=$((current_minor + 1));;
        patch) current_patch=$((current_patch + 1));;
    esac

    read -r new_version <<< "$(printf -- '%d.%d.%d' "$current_major" "$current_minor" " $current_patch")"
    printf -- '%s\n' "$new_version" > "$PROJECT_PATH/packages/$package_name/VERSION"

    git add -- "$PROJECT_PATH/packages/$package_name/VERSION"
    git commit -m "Release: ${package_name} v${new_version}"
    git tag "v${new_version}-${package_name}"

}

release "$1" "$2"
