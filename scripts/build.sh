#!/bin/bash

set -e

if ! type jq &> /dev/null; then
    printf -- 'Missing dependency jq, to install it run the following:\n\nsudo apt install jq\n' >&2
    exit 1
fi

PROJECT_PATH=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

build-create-task-runner() {
    local jq_filter package_version package_name='create-task-runner' sed_replace
    package_version="$(head -n1 < "$PROJECT_PATH/packages/$package_name/VERSION")"

    read -r jq_filter <<< "$(printf -- '.name="@orbit-online/%s" | .version="%s" | del(.devDependencies,.bin.orb,.private)' "$package_name" "$package_version")"
    read -r sed_replace <<< "$(printf -- 's/v__VERSION__/v%s/' "$package_version")"

    mkdir -p "$PROJECT_PATH/packages/$package_name/bin"
    jq "$jq_filter" < package.json > "$PROJECT_PATH/packages/$package_name/package.json"

    cp "$PROJECT_PATH/bin/install-task-runner."* "$PROJECT_PATH/packages/$package_name/bin/"
    sed -i "$sed_replace" "$PROJECT_PATH/packages/$package_name/bin/install-task-runner.sh"
    cp "$PROJECT_PATH/LICENSE" "$PROJECT_PATH/packages/$package_name"
}

build-task-runner() {
    local jq_filter package_version package_name='task-runner' sed_replace
    package_version="$(head -n1 < "$PROJECT_PATH/packages/$package_name/VERSION")"

    read -r jq_filter <<< "$(printf -- '.name="@orbit-online/%s" | .version="%s" | del(.dependencies,.devDependencies,.bin."create-task-runner",.private)' "$package_name" "$package_version")"
    read -r sed_replace <<< "$(printf -- 's/v__VERSION__/v%s/' "$package_version")"

    mkdir -p "$PROJECT_PATH/packages/$package_name/bin"
    jq "$jq_filter" < package.json > "$PROJECT_PATH/packages/$package_name/package.json"

    cp "$PROJECT_PATH/bin/orbit-task-runner.sh" "$PROJECT_PATH/packages/$package_name/bin/"
    sed -i "$sed_replace" "$PROJECT_PATH/packages/$package_name/bin/orbit-task-runner.sh"
    cp -R "$PROJECT_PATH/completions/" "$PROJECT_PATH/packages/$package_name/completions/"
    cp "$PROJECT_PATH/LICENSE" "$PROJECT_PATH/packages/$package_name"
}

build() {
    if [ -z "$1" ] || [[ $1 == 'create-task-runner' ]]; then
        build-create-task-runner
    fi
    if [ -z "$1" ] || [[ $1 == 'task-runner' ]]; then
        build-task-runner
    fi
}

clean-create-task-runner() {
    local package_name='create-task-runner'
    git clean -fdX -- "$PROJECT_PATH/packages/$package_name" > /dev/null
}

clean-task-runner() {
    local package_name='task-runner'
    git clean -fdX -- "$PROJECT_PATH/packages/$package_name" > /dev/null
}

clean() {
    if [ -z "$1" ] || [[ $1 == 'create-task-runner' ]]; then
        clean-create-task-runner
    fi
    if [ -z "$1" ] || [[ $1 == 'task-runner' ]]; then
        clean-task-runner
    fi
}

clean "$@"
build "$@"
