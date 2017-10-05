#!/usr/bin/env bash

##################
# Console Utilties
##################

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
    if [[ -z "$WARDEN_HOME" ]]; then
        console_error "WARDEN_HOME not set..."
        return 1
    fi

    if [[ -z "$WARDEN_OS_ARCH" ]]; then
        console_error "WARDEN_OS_ARCH not set..."
        return 1
    fi

    if [[ -z "$WARDEN_VERSION" ]]; then
        console_error "WARDEN_VERSION not set..."
        return 1
    fi

    if [[ -z "$WARDEN_AUTO_UPDATE_INTERVAL" ]]; then
        console_error "WARDEN_AUTO_UPDATE_INTERVAL not set..."
        return 1
    fi
}

##################
# Github Functions
##################

get_latest_version() {
	curl -fsSL "https://api.github.com/repos/warden-pub/warden-releases/releases/latest" | $GREP_EXTENDED -o '"tag_name":.*?[^\\]\",' | $SED_EXTENDED 's/^ *//;s/.*: *"//;s/",?//'
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

    echo "$WARDEN_HOME/versions/$version"
}

get_version_binary_path() {
	if [[ $# -ne 1 ]]; then
		console_error "get_version_binary_path requires arguments: version"
		return 1
	fi

    local version=$1

    echo "$(get_version_directory $version)/warden"
}

get_env_path() {
	echo "$WARDEN_HOME/env.sh"
}

set_last_update_check() {
    if [[ $# -ne 1 ]]; then
		console_error "update_last_update_check requires arguments: time_in_seconds_past_epoch"
		return 1
	fi

    local time_in_seconds_past_epoch=$1

    echo $time_in_seconds_past_epoch > "$WARDEN_HOME/check"
}

get_last_update_check() {
    [[ -e "$WARDEN_HOME/check" ]] && cat "$WARDEN_HOME/check"
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

    [[ $(($last_update_check+$WARDEN_AUTO_UPDATE_INTERVAL)) -le $now ]]
}

update() {
    if [[ $# -ne 1 ]]; then
		console_error "update requires arguments: latest_version"
		return 1
	fi

	latest_version=$1

    bash <(curl -fsSL https://raw.githubusercontent.com/NoFateLLC/warden-releases/master/scripts/install.sh) $latest_version
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
        console_error "Error updating warden to version $latest_version"
        exit 1
    fi
    exit
fi

cmd="$(get_version_binary_path $WARDEN_VERSION)"

if ! should_update_check; then
    exec env WARDEN_VERSION=$WARDEN_VERSION $cmd "$@"
fi

latest_version="$(get_latest_version)"

if is_version_installed $latest_version; then
    exec env WARDEN_VERSION=$latest_version $cmd "$@"
fi

console_info "The latest version is $latest_version. You are using $WARDEN_VERSION. Updating now..."
if ! update $latest_version; then
    console_error "Error updating warden to version $latest_version"

    exec env WARDEN_VERSION=$latest_version $cmd "$@"
fi

exec env WARDEN_VERSION=$latest_version "$(get_version_binary_path $latest_version)" "$@"
