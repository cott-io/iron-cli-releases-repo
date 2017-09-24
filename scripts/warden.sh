#!/usr/bin/env bash

GITHUB_API_RELEASES_REPO_URL="https://api.github.com/repos/NoFateLLC/warden-releases"
GITHUB_RELEASES_DOWNLOAD_URL="https://github.com/nofatellc/warden-releases/releases/download"

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

auto_update() {
	version=$1

	latest_version="$(get_latest_version)"

	if [[ $latest_version == $version ]]; then
		return
	fi

	console_info "The latest version is $latest_version. You are using $version."
	read -p "Do you want to upgrade to $latest_version? [yN]" upgrade_prompt
	case $upgrade_prompt in
		[Yy]* )
			exec "$(get_binary_directory)/warden" $latest_version
			break;;
		[Nn]* )
			return;;
		* )
			return;;
	esac
}

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

# Main
set_os_specific_commands
if ! verify_env; then
    exit $?
fi

if [ ! -e "$(get_version_binary_path $WARDEN_VERSION)" ]; then
    download_warden $WARDEN_VERSION
    if [[ $? -ne 0 ]]; then
        exit $?
    fi
fi

exec "$(get_version_binary_path $WARDEN_VERSION)" "$@"
