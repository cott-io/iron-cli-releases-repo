#!/usr/bin/env bash

###########
# Constants
###########

GITHUB_API_RELEASES_REPO_URL="https://api.github.com/repos/NoFateLLC/warden-releases"
GITHUB_RELEASES_DOWNLOAD_URL="https://github.com/nofatellc/warden-releases/releases/download"

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
	curl -fsSL "$GITHUB_API_RELEASES_REPO_URL/releases/latest" | $GREP_EXTENDED -o '"tag_name":.*?[^\\]\",' | $SED_EXTENDED 's/^ *//;s/.*: *"//;s/",?//'
}

###########################
# Warden Dirctory Structure
###########################

get_version_directory() {
	if [[ $# -ne 1 ]]; then
		console_error "get_version_directory requires arguments: version"
		return 1
	fi

    version=$1

    echo "$WARDEN_HOME/versions/$version"
}

get_version_binary_path() {
	if [[ $# -ne 1 ]]; then
		console_error "get_version_binary_path requires arguments: version"
		return 1
	fi

    version=$1

    echo "$(get_version_directory $version)/warden"
}

get_env_path() {
	echo "$WARDEN_HOME/env.sh"
}

#####################
# Local Install State
#####################

is_version_installed() {
	if [[ $# -ne 1 ]]; then
		console_error "is_version_installed requires arguments: version"
		return 1
	fi

    version=$1

	[[ -e "$(get_version_binary_path $version)" ]] && grep -q "$version" "$(get_env_path)" && [[ $WARDEN_VERSION = $version ]]
}



########
# Update
########

auto_update() {
	version=$1

	latest_version="$(get_latest_version)"

	if is_version_installed $latest_version; then
		return 0
	fi

	console_info "The latest version is $latest_version. You are using $version. Updating now..."


}

########
# Main #
########

set_os_specific_commands

if ! verify_env; then
    exit $?
fi

if ! is_version_installed $WARDEN_VERSION; then
    console_error "$WARDEN_VERSION not installed..."
    exit 1
fi

exec "$(get_version_binary_path $WARDEN_VERSION)" "$@"
