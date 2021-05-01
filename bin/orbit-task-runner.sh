#!/bin/bash

# Only define the ot function if it is called directly
# or if the invocation if orb is nested due to local copy invocation,
# or if there is no orb excutable in PATH.
if [[ $_ORB_LOCAL_INVOKE || "$(realpath "$0")" = "$(realpath "${BASH_SOURCE[0]}")" ]] || ! type -P orb &> /dev/null; then
orb() {
    if [ -z "$1" ]; then
        printf -- 'Usage: orb TASK [ TASKARGS... ]\n' >&2
        return 1
    elif [[ "$1" == '--version' ]]; then
        printf -- 'v__VERSION__\n'
        return 0
    fi

    __orb_find_project_root() {
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

    __orb_find_tasks() {
        local perm task_name=$1 unamestr
        local -a find_args=()

        unamestr=$(uname)
        if [[ $unamestr == 'Darwin' || $unamestr == 'FreeBSD' ]]; then
            perm='+ugo+x'
        else
            perm='/ugo+x'
        fi

        ! ${ORB_BIN_PATH_RECURSE:-false} && find_args+=( "-maxdepth 1" )
        [[ -n "$task_name" && "$task_name" != '*' ]] && find_args+=( "( -name $task_name -o -name $task_name.* )" )

        # Don't show orb as result unless specifically queried after.
        [[ ! "$task_name" =~ ^orb|\*|o\*|or\*|orb\*$ ]] && find_args+=( "-not -name orb" )

        set -o noglob
        # shellcheck disable=2086
        find \
            "${ORB_BIN_PATHS[@]}" \
            ${find_args[*]} \
            -perm "$perm" \
            -not -type d \
            -print0
        set +o noglob
    }

    __orb_load_dotenv() {
        if [ -f "$ORB_PROJECT_PATH/.env" ]; then
            __orb_read_dotenv_file "$ORB_PROJECT_PATH/.env"
        elif [ -f "$ORB_PROJECT_PATH/config/.env" ]; then
            __orb_read_dotenv_file "$ORB_PROJECT_PATH/config/.env"
        elif [ -f "$ORB_PROJECT_PATH/config/env" ]; then
            __orb_read_dotenv_file "$ORB_PROJECT_PATH/config/env"
        elif [ -f "$ORB_PROJECT_PATH/.config/env" ]; then
            __orb_read_dotenv_file "$ORB_PROJECT_PATH/.config/env"
        elif [ -f "$ORB_PROJECT_PATH/.config/.env" ]; then
            __orb_read_dotenv_file "$ORB_PROJECT_PATH/.config/.env"
        fi
    }

    __orb_read_dotenv_file() {
        local raw_env_line dotenv_file=$1
        while IFS= read -r raw_env_line; do
            [[ -z $raw_env_line || $raw_env_line = '#'* ]] && continue
            eval "export $raw_env_line"
        done < "$dotenv_file"
    }

    __orb_typeset_dotenv() {
        __orb_read_dotenv_file() {
            local raw_env_line dotenv_file=$1
            while IFS= read -r raw_env_line; do
                [[ -z $raw_env_line || \
                      $raw_env_line == '#'* || \
                      $raw_env_line == 'ORB_BIN_PATHS='* || \
                      $raw_env_line == 'ORB_PROJECT_PATH='* || \
                      $raw_env_line == 'PROJECT_PATH='* \
                ]] && continue
                printf -- "typeset -- %s\n" "$raw_env_line"
            done < "$dotenv_file"
        }
        __orb_load_dotenv
    }

    __orb_get_task_path() {
        local task_path task_name=$1
        task_path=$(__orb_find_tasks "$task_name" | tr '\0' '\n')

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

    __orb_run_task() {
        local task_name=$1 task_path
        if ! task_path=$(__orb_get_task_path "$task_name"); then
            return 1
        fi

        shift
        exec "$task_path" "$@"
    }

    if [ -z "$ORB_PROJECT_PATH" ]; then
        if [ -n "$PROJECT_PATH" ]; then
            ORB_PROJECT_PATH="$PROJECT_PATH"
        else
            ORB_PROJECT_PATH=$(__orb_find_project_root)
            export PROJECT_PATH=$ORB_PROJECT_PATH
        fi
    fi

    if [ -z "$PROJECT_PATH" ]; then
        PROJECT_PATH="$ORB_PROJECT_PATH"
    fi

    local -a ORB_BIN_PATHS=
    __orb_load_dotenv

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
                local_orb=
                break
            fi

            break
        done < <(__orb_find_tasks orb)
        if [ -n "$local_orb" ]; then
            ( set -e; _ORB_LOCAL_INVOKE=true "$local_orb" "$@" )
            return $?
        fi
    fi

    if [ "$1" == '--list' ]; then
        ( set -e; __orb_find_tasks "$2" | tr '\0' '\n' )
    elif [ "$1" == '--env' ]; then
        local bin_path
        printf -- 'typeset -- PROJECT_PATH="%q"\n' "$PROJECT_PATH"
        printf -- 'typeset -- ORB_PROJECT_PATH="%q"\n' "$ORB_PROJECT_PATH"
        printf -- 'typeset -a ORB_BIN_PATHS=('; for bin_path in "${ORB_BIN_PATHS[@]}"; do printf -- ' "%q"' "$bin_path"; done; printf ' )\n'
        __orb_typeset_dotenv
    else
        ( set -e; __orb_run_task "$@" )
        return $?
    fi
}
fi

# Only invoke the orb function this script is called directly.
if [[ $_ORB_LOCAL_INVOKE || "${BASH_SOURCE[0]}" = 'orb' || "$(realpath "$0")" = "$(realpath "${BASH_SOURCE[0]}")" ]]; then
    orb "$@"
fi
