#!/bin/bash

set -e

PROJECT_PATH=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

publish() {
    if [ -z "$1" ] || [[ "$1" != 'task-runner' && $1 != 'create-task-runner' ]]; then
        printf -- 'Usage: publish.sh task-runner | create-task-runner\n' >&2
        exit 1
    fi
    local package_name=$1

    cd "$PROJECT_PATH/packages/$package_name"
    npm publish --access=public
}

publish "$1"
