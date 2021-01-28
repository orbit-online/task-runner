#!/bin/bash

# Only define the ot function if it is called directly
# or if the invocation if orb is nested due to local copy invocation,
# or if there is no orb excutable in PATH.
if [[ $_ORB_LOCAL_INVOKE || "$(realpath "$0")" = "$(realpath "${BASH_SOURCE[0]}")" ]] || ! type -P orb &> /dev/null; then
orb() {
    if [ -z "$1" ]; then
        printf -- 'Usage: orb TASK [ TASKARGS... ]\n' >&2
        return 1
    fi

    find_project_root() {
        local path
        path="$(pwd)"
        while [ "$path" != '/' ] ; do
            if [[ -d "$path/.git" || -f "$path/.env" || -f "$path/package.json" ]]; then
                printf -- '%s' "$path"
                return 0
            fi
            path="$(dirname "$path")"
        done
        return 1
    }

    find_tasks() {
        local maxdepth=${ORB_BIN_PATH_RECURSE:-false} perm task_name=$1 unamestr

        unamestr=$(uname)
        if [[ $unamestr == 'Darwin' || $unamestr == 'FreeBSD' ]]; then
            perm='+ugo+x'
        else
            perm='/ugo+x'
        fi

        if $maxdepth; then
            maxdepth=''
        else
            maxdepth="-maxdepth 1"
        fi

        # shellcheck disable=2086
        find \
            "${ORB_BIN_PATHS[@]}" \
            $maxdepth \
            -perm "$perm" \
            \( -name "$task_name" -o -name "$task_name.*" \) \
            -not -type d \
            -print0
    }

    load_dotenv() {
        if [ -f "$ORB_PROJECT_PATH/.env" ]; then
            read_dotenv_file "$ORB_PROJECT_PATH/.env"
        elif [ -f "$ORB_PROJECT_PATH/config/.env" ]; then
            read_dotenv_file "$ORB_PROJECT_PATH/config/.env"
        elif [ -f "$ORB_PROJECT_PATH/config/env" ]; then
            read_dotenv_file "$ORB_PROJECT_PATH/config/env"
        elif [ -f "$ORB_PROJECT_PATH/.config/env" ]; then
            read_dotenv_file "$ORB_PROJECT_PATH/.config/env"
        elif [ -f "$ORB_PROJECT_PATH/.config/.env" ]; then
            read_dotenv_file "$ORB_PROJECT_PATH/.config/.env"
        fi
    }

    read_dotenv_file() {
        local raw_env_line dotenv_file=$1
        while IFS= read -r raw_env_line; do
            [[ -z $raw_env_line || $raw_env_line = '#'* ]] && continue
            eval "export $raw_env_line"
        done < "$dotenv_file"
    }

    get_task_path() {
        local task_path task_name=$1
        task_path=$(find_tasks "$task_name" | tr '\0' '\n')

        if [[ -z $task_path ]]; then
            printf -- 'Unable to find any tasks matching "%s"\n' "$task_name" >&2
            printf -- 'Searched for task in:\n' >&2
            printf -- '- %s\n' "${ORB_BIN_PATHS[@]}" >&2
            return 1
        fi

        if (( $(wc -l <<< "$task_path") > 1 )); then
            printf -- 'Found multiple tasks matching "%s":\n' "$task_name" >&2
            printf -- '%s\n' "${task_path[@]}" >&2
            return 1
        fi

        printf -- '%s\n' "$task_path"
        return 0
    }

    run_task() {
        local task_name=$1 task_path
        if ! task_path=$(get_task_path "$task_name"); then
            return 1
        fi

        shift
        exec "$task_path" "$@"
    }

    if [ -z "$ORB_PROJECT_PATH" ]; then
        if [ -n "$PROJECT_PATH" ]; then
            ORB_PROJECT_PATH="$PROJECT_PATH"
        else
            ORB_PROJECT_PATH=$(find_project_root)
            export PROJECT_PATH=$ORB_PROJECT_PATH
        fi
    fi

    if [ -z "$PROJECT_PATH" ]; then
        PROJECT_PATH="$ORB_PROJECT_PATH"
    fi

    ORB_BIN_PATHS=
    load_dotenv

    if [ -z "$ORB_BIN_PATHS" ]; then
        ORB_BIN_PATHS=()
        [ -d "$ORB_PROJECT_PATH/.bin" ] && ORB_BIN_PATHS+=( "$ORB_PROJECT_PATH/.bin" )
        [ -d "$ORB_PROJECT_PATH/bin" ] && ORB_BIN_PATHS+=( "$ORB_PROJECT_PATH/bin" )
        [ -d "$ORB_PROJECT_PATH/scripts" ] && ORB_BIN_PATHS+=( "$ORB_PROJECT_PATH/scripts" )
        [ -d "$ORB_PROJECT_PATH/tasks" ] && ORB_BIN_PATHS+=( "$ORB_PROJECT_PATH/tasks" )
        [ -d "$ORB_PROJECT_PATH/tools" ] && ORB_BIN_PATHS+=( "$ORB_PROJECT_PATH/tools" )
    fi

    if [[ $ORB_NODE_MODULES ]]; then
        [ -d "$ORB_PROJECT_PATH/node_modules/.bin" ] && ORB_BIN_PATHS+=( "$ORB_PROJECT_PATH/node_modules/.bin" )
    fi

    if [[ $ORB_HOME_BIN ]]; then
        [ -d "$HOME/.local/bin" ] && ORB_BIN_PATHS+=( "$HOME/.local/bin" )
        [ -d "$HOME/.bin" ] && ORB_BIN_PATHS+=( "$HOME/.bin" )
        [ -d "$HOME/bin" ] && ORB_BIN_PATHS+=( "$HOME/bin" )
    fi

    if [ -z "$_ORB_LOCAL_INVOKE" ]; then
        local local_orb
        while IFS= read -r -d '' local_orb; do
            if [ "$(realpath "$local_orb")" = "$(realpath "${BASH_SOURCE[0]}")" ]; then
                break
            fi

            (
                set -e
                _ORB_LOCAL_INVOKE=true "$local_orb" "$@"
            )
            return $?
        done < <(find_tasks orb)
    fi

    (
        set -e
        run_task "$@"
    )
}
fi

# Only invoke the orb function this script is called directly.
if [[ $_ORB_LOCAL_INVOKE || "${BASH_SOURCE[0]}" = 'orb' || "$(realpath "$0")" = "$(realpath "${BASH_SOURCE[0]}")" ]]; then
    orb "$@"
fi
