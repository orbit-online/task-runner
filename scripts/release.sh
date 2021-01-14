#!/bin/bash

set -e

PROJECT_PATH=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

release() {
    local program
    program="$(basename "${BASH_SOURCE[0]}")"

    local DOC="Usage:
    ${program} PACAKGE COMMAND [MODIFIER]
    ${program} PACKAGE major|minor|patch [alpha|beta|rc]
    ${program} PACKAGE alpha|beta|rc
    ${program} PACKAGE pre-release
" DOC_HELP='
Packages:
  task-runner
  create-task-runner

Command:
  major          Bump the package to the next major version.
  minor          Bump the package to the next minor version.
  patch          Bump the package to the next patch version.
  alpha          Bump the package to the next alpha pre-release version, if the pacakge is not currently in a pre-release an error is returned.
  beta           Bump the package to the next beta pre-release version, if the pacakge is not currently in a pre-release an error is returned.
  rc             Bump the package to the next rc pre-release version, if the pacakge is not currently in a pre-release an error is returned.
  pre-release    Release the non-pre-release version of the pacakge, if the package is not currently in a pre-release an error is returned.

Modifier:
  alpha          Add alpha pre-release suffix to the version bump
  beta           Add beta pre-release suffix to the version bump
  rc             Add rc pre-release suffix to the version bump

Examples:
  Bump package from alpha to beta version.         (e.g. 1.2.5-alpha.4 -> 1.2.5-beta.1)
    $ ./release.sh task-runner beta
  Bump rc of a package already in rc pre-release.  (e.g. 1.2.6-rc.2 -> 1.2.6-rc.3)
    $ ./release.sh task-runner rc
  Bump minor version as an alpha pre-release.      (e.g. 1.2.7 -> 1.3.0-alpha.1)
    $ ./release.sh task-runner minor alpha
  Bump major version of the package.               (e.g. 1.2.8 -> 2.0.0)
    $ ./release.sh task-runner major

'
    if [[ "$1" == '--help' || "$1" == '-h' ]]; then
        printf -- '%s' "$DOC" "$DOC_HELP" >&2
        exit 1
    fi

    if ! [[ -n "$1" && -n "$2" ]] || \
       ! [[ "$1" =~ ^task-runner|create-task-runner$ ]] || \
       ! [[ "$2" =~ ^pre-release|major|minor|patch|alpha|beta|rc$ ]]
    then
        printf -- '%s' "$DOC" >&2
        exit 1
    fi

    local new_pre_release_name
    if [[ -n $3 ]]; then
        if ! [[ $3 =~ ^alpha|beta|rc$ ]] || \
             [[ $2 =~ ^alpha|beta|rc$ ]]
        then
            printf -- '%s' "$DOC" >&2
            exit 1
        fi
        new_pre_release_name=$3
    elif [[ $2 =~ ^alpha|beta|rc$ ]]; then
        new_pre_release_name=$2
    fi

    local package_name=$1 version_bump=$2 \
          current_major current_minor current_patch current_pre_release current_version new_version \
          current_pre_release_name current_pre_release_version \
          git_commit_msg git_release_tag version_path

    version_path="$PROJECT_PATH/packages/$package_name/VERSION"

    if [[ -n $(git diff -- "$version_path") ]]; then
        printf -- 'The VERSION file of the %s package has uncomitted changes,\nplease commit them or reset the changes and try again.\n' "$package_name" >&2
        exit 1
    fi
    if [[ -n $(git diff --staged) ]]; then
        printf -- 'There are staged changes in the git working copy, please unstage the changes and try again.\n' >&2
        exit 1
    fi

    current_major=$(grep -oP '^\K(\d+)' < "$version_path")
    current_minor=$(grep -oP '^\d+\.\K(\d+)' < "$version_path")
    current_patch=$(grep -oP '^\d+\.\d+\.\K(\d+)' < "$version_path")
    current_pre_release=$(grep -oP '^\d+\.\d+\.\d+-\K(.+)' < "$version_path" 2>/dev/null || printf -- '')

    if [[ -n "$current_pre_release" ]]; then
        read -r current_version <<< "$(printf -- '%d.%d.%d-%s' "$current_major" "$current_minor" " $current_patch" "$current_pre_release" )"
        current_pre_release_name=$(grep -oP '^\d+\.\d+\.\d+-\K(alpha|beta|rc)' < "$version_path" 2>/dev/null || printf -- '')
        current_pre_release_version=$(grep -oP '^\d+\.\d+\.\d+-\w+\.\K(\d+)' < "$version_path" 2>/dev/null || printf -- '0')
    else
        read -r current_version <<< "$(printf -- '%d.%d.%d' "$current_major" "$current_minor" " $current_patch")"
        if [[ "$version_bump" == 'pre-release' ]]; then
            printf -- 'The package must currently be a pre-release in order to use the pre-release command.\n%s is currently in %s which is not a pre-release.\n' "$package_name" "$current_version" >&2
            exit 1
        fi
    fi

    case "$version_bump" in
        major)
            current_major=$((current_major + 1))
            current_minor=0
            current_patch=0
            current_pre_release_name=alpha
            current_pre_release_version=0
            ;;
        minor)
            current_minor=$((current_minor + 1))
            current_patch=0
            current_pre_release_name=alpha
            current_pre_release_version=0
            ;;
        patch)
            current_patch=$((current_patch + 1))
            current_pre_release_name=alpha
            current_pre_release_version=0
            ;;
    esac

    if [[ -n "$new_pre_release_name" ]]; then
        if [[ "$new_pre_release_name" == "$current_pre_release_name" ]]; then
            current_pre_release_version=$((current_pre_release_version + 1))
        elif [[ "$new_pre_release_name" =~ ^beta|rc$ && "$current_pre_release_name" == 'alpha' ]] || \
             [[ "$new_pre_release_name" = 'rc' && "$current_pre_release_name" =~ ^alpha|beta$ ]]; then
            current_pre_release_version="1"
        else
            if [[ -z "$current_pre_release_name" ]]; then
                printf -- 'Cannot bump %s pre-release from a non-pre-release without bumping version number as well.\n' "$new_pre_release_name" >&2
            else
                printf -- 'Cannot bump pre-release from %s to %s\n' "$current_pre_release_name" "$new_pre_release_name" >&2
            fi
            exit 1
        fi
        read -r new_version <<< "$(printf -- '%d.%d.%d-%s.%d' "$current_major" "$current_minor" " $current_patch" "$new_pre_release_name" "$current_pre_release_version" )"
    else
        read -r new_version <<< "$(printf -- '%d.%d.%d' "$current_major" "$current_minor" " $current_patch")"
    fi

    printf -- '%s\n' "$new_version" > "$version_path"

    git_commit_msg="Release: ${package_name} v${new_version}"
    git_release_tag="v${new_version}-${package_name}"

    git add -- "$version_path" > /dev/null
    git commit -m "$git_commit_msg" > /dev/null
    git tag "$git_release_tag" > /dev/null

    printf -- 'Bumped the version of %s from %s -> %s\nupdated VERSION file, committed the changes with the release message:\n\n%s\n\ntagged the commit with:\n\n%s\n\nDon'\''t forget to push both the branch and the tag e.g. by running:\n\n$ git push && git push --tags\n' "$package_name" "$current_version" "$new_version" "$git_commit_msg" "$git_release_tag"
}

release "$@"
