#!/bin/bash

set -e

PROJECT_PATH=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

build-create-task-runner() {
    local jq_filter package_version package_name='create-task-runner'
    package_version="$(head -n1 < "$PROJECT_PATH/packages/$package_name/VERSION")"

    read -r jq_filter <<< "$(printf -- '.name="@orbit-online/%s" | .version="%s" | del(.devDependencies,.bin.orb,.private)' "$package_name" "$package_version")"

    mkdir -p "$PROJECT_PATH/packages/$package_name/bin"
    jq "$jq_filter" < package.json > "$PROJECT_PATH/packages/$package_name/package.json"

    cp "$PROJECT_PATH/bin/install-task-runner.sh" "$PROJECT_PATH/packages/$package_name/bin/"
    cp "$PROJECT_PATH/LICENSE" "$PROJECT_PATH/packages/$package_name"
}

build-task-runner() {
    local jq_filter package_version package_name='task-runner'
    package_version="$(head -n1 < "$PROJECT_PATH/packages/$package_name/VERSION")"

    read -r jq_filter <<< "$(printf -- '.name="@orbit-online/%s" | .version="%s" | del(.dependencies,.devDependencies,.bin."create-task-runner",.private)' "$package_name" "$package_version")"

    mkdir -p "$PROJECT_PATH/packages/$package_name/bin"
    jq "$jq_filter" < package.json > "$PROJECT_PATH/packages/$package_name/package.json"

    cp "$PROJECT_PATH/bin/orbit-task-runner.sh" "$PROJECT_PATH/packages/$package_name/bin/"
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