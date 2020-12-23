#!/bin/bash

install_orb() {
    local install_cmd=() task_runner_path task_runner_name=${1:-orb} prefix=${ORB_INSTALL_PREFIX:-/usr/local/bin}
    if [[ ! -d $prefix ]]; then
        printf -- '%s is not a directory choose different install prefix by setting the ORB_INSTALL_PREFIX environment variable\n' "$prefix" >&2
        exit 1
    fi
    if [ ! -w "$prefix" ]; then
        install_cmd+=( "sudo" )
    fi

    task_runner_path="$(realpath "$(dirname "${BASH_SOURCE[0]}")/orb")"
    install_cmd+=( "cp" "$task_runner_path" "$prefix/$task_runner_name" )

    if (
        set -e
        "${install_cmd[@]}"
    ); then
        printf -- 'Succesfully installed the task runner at %s/%s\n' "$prefix" "$task_runner_name"
    else
        printf -- 'Could not install the task runner at %s/%s\n' "$prefix" "$task_runner_name" >&2
        return 1
    fi

    if [ -f package.json ]; then
        local err status=0
        if [ -f yarn.lock ] && type yarn &> /dev/null; then
            err=$(yarn add -D @orbit-online/create-task-runner 2>&1) || status=$?
        elif type npm &> /dev/null; then
            err=$(npm install --save-dev @orbit-online/create-task-runner 2>&1) || status=$?
        fi

        if [[ $status != 0 ]]; then
            printf -- '%s\n' "$err" >&2
            printf -- 'Failed to add @orbit-online/create-task-runner as local devDependency to package.json\n' >&2
            return 1
        fi
    fi
}

install_orb "$@"
