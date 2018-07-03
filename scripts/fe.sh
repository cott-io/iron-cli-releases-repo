#!/usr/bin/env bash

##################
# Console Utilties
##################

# The repo where the release artifacts are held
IRON_RELEASE_REPO=${IRON_RELEASE_REPO:-"https://github.com/cott-io/iron-releases"}

# The branch of the scripts repo where the install/update scripts are held
IRON_SCRIPTS_REF=${IRON_SCRIPTS_REF:-"master"}

# The url of the api call for determining the latest artifact
IRON_LATEST_URL=${IRON_RELEASE_REPO/https:\/\/github.com/https:\/\/api.github.com\/repos}/releases/latest

# The url of the installer script source code
IRON_INSTALL_URL=${IRON_INSTALL_URL:-"https://dev.cott.io/docs/install.sh"}

console_info() {
    if ! tput setaf &>/dev/null; then
        echo "$1"
    else
        echo "$(tput setaf 2)$1$(tput sgr0)"
    fi
}

console_error() {
    if ! tput setaf &>/dev/null; then
        echo "$1" 1>&2
    else
        echo "$(tput setaf 1)$1$(tput sgr0)" 1>&2
    fi
}

##########################
# OS / Shell Compatibility
##########################

set_os_specific_commands() {
    uname=$(uname)
    if [[ "$uname" == 'Linux' ]]; then
        SED_EXTENDED="sed -r"
        GREP_EXTENDED="grep -P"
        MD5="md5sum"
    elif [[ "$uname" == 'Darwin' ]]; then
        SED_EXTENDED="sed -E"
        GREP_EXTENDED="grep -E"
        MD5="md5 -r"
    fi
}

#############
# Environment
#############

verify_env() {
    if [[ -z "$IRON_HOME" ]]; then
        console_error "IRON_HOME not set..."
        return 1
    fi

    if [[ -z "$IRON_OS_ARCH" ]]; then
        console_error "IRON_OS_ARCH not set..."
        return 1
    fi

    if [[ -z "$IRON_VERSION" ]]; then
        console_error "IRON_VERSION not set..."
        return 1
    fi

    if [[ -z "$IRON_AUTO_UPDATE_INTERVAL" ]]; then
        console_error "IRON_AUTO_UPDATE_INTERVAL not set..."
        return 1
    fi
}

##################
# Github Functions
##################

get_latest_version() {
    curl -fsSL "$IRON_LATEST_URL" | $GREP_EXTENDED -o '"tag_name":.*?[^\\]\",' | $SED_EXTENDED 's/^ *//;s/.*: *"//;s/",?//'
}

###########################
# Warden Dirctory Structure
###########################

get_version_directory() {
    if [[ $# -ne 1 ]]; then
        console_error "get_version_directory requires arguments: version"
        return 1
    fi

    local version=$1

    echo "$IRON_HOME/versions/$version"
}

get_version_binary_path() {
    if [[ $# -ne 1 ]]; then
        console_error "get_version_binary_path requires arguments: version"
        return 1
    fi

    local version=$1

    echo "$(get_version_directory $version)/fe"
}

get_env_path() {
    echo "$IRON_HOME/env.sh"
}

set_last_update_check() {
    if [[ $# -ne 1 ]]; then
        console_error "update_last_update_check requires arguments: time_in_seconds_past_epoch"
        return 1
    fi

    local time_in_seconds_past_epoch=$1

    echo $time_in_seconds_past_epoch > "$IRON_HOME/check"
}

get_last_update_check() {
    [[ -e "$IRON_HOME/check" ]] && cat "$IRON_HOME/check"
}

#####################
# Local Install State
#####################

is_version_installed() {
    if [[ $# -ne 1 ]]; then
        console_error "is_version_installed requires arguments: version"
        return 1
    fi

    local version=$1

    [[ -e "$(get_version_binary_path $version)" ]] && grep -q "$version" "$(get_env_path)"
}

########
# Update
########

should_update_check() {
    local now=$(date +"%s")
    local local_last_check=$(get_last_update_check)
    local last_update_check=${local_last_check:-$now}

    set_last_update_check $now

    [[ $(($last_update_check+$IRON_AUTO_UPDATE_INTERVAL)) -le $now ]]
}

update() {
    if [[ $# -ne 1 ]]; then
        console_error "update requires arguments: latest_version"
        return 1
    fi

    latest_version=$1

    bash <(curl -fsSL $IRON_INSTALL_URL) $latest_version
}

########
# Main #
########

set_os_specific_commands

if ! verify_env; then
    exit $?
fi

if [[ $1 == "update" ]]; then
    latest_version="$(get_latest_version)"

    if ! update $latest_version; then
        console_error "Error updating iron to version $latest_version"
        exit 1
    fi
    exit
fi

cmd="$(get_version_binary_path $IRON_VERSION)"

if ! should_update_check; then
    exec env IRON_VERSION=$IRON_VERSION $cmd "$@"
fi

latest_version="$(get_latest_version)"

if is_version_installed $latest_version; then
    exec env IRON_VERSION=$latest_version $cmd "$@"
fi

console_info "The latest version is $latest_version. You are using $IRON_VERSION. Updating now..."
if ! update $latest_version; then
    console_error "Error updating iron to version $latest_version"

    exec env IRON_VERSION=$latest_version $cmd "$@"
fi

exec env IRON_VERSION=$latest_version "$(get_version_binary_path $latest_version)" "$@"
