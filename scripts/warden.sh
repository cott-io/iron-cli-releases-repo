#!/usr/bin/env bash

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

GITHUB_API_RELEASES_REPO_URL="https://api.github.com/repos/NoFateLLC/warden-releases"
GITHUB_RELEASES_DOWNLOAD_URL="https://github.com/nofatellc/warden-releases/releases/download"

semver_parse() {
	major="${1%%.*}"
	minor="${1#$major.}"
	minor="${minor%%.*}"
	patch="${1#$major.$minor.}"
	patch="${patch%%[-.]*}"
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

read_tag_name() {
	$GREP_EXTENDED -o '"tag_name":.*?[^\\]\",' | $SED_EXTENDED 's/^ *//;s/.*: *"//;s/",?//'
}

read_md5() {
	$GREP_EXTENDED -o "^\w+"
}

get_binary_directory() {
	echo "$WARDEN_HOME/bin"
}

get_version_directory() {
	version=$1

	echo "$WARDEN_HOME/versions/$version"
}

get_version_remote_md5() {
	version=$1

	md5_url="$(get_version_release_url $version).md5"

	md5="$(curl -fsSL "$md5_url")"
	if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
		console_error "Error downloading $md5_url"
		return 1
	fi

	echo $md5
}

get_latest_version() {
	curl -fsSL "$GITHUB_API_RELEASES_REPO_URL/releases/latest" | read_tag_name
}

get_release_filename() {
    echo "warden-$WARDEN_OS_ARCH.tar.gz"
}

get_version_release_url() {
	version=$1

	release_filename="$(get_release_filename)"
	echo "$GITHUB_RELEASES_DOWNLOAD_URL/$version/$release_filename"
}

get_version_binary_path() {
	version=$1

	echo "$(get_version_directory $version)/warden"
}

update() {
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

download_warden() {
	version=$1
	
	console_info "Downloading warden version: [$version] platform: [$WARDEN_OS_ARCH]..."

    release_filename="$(get_release_filename)"
	download_url="$(get_version_release_url $version)"

	mkdir -p "$(get_version_directory $version)"

    release_tar_path="$(get_version_directory $version)/$release_filename"

	curl -fsSL "$download_url" > $release_tar_path
	if [[ $? -ne 0 ]]; then
		console_error "Error downloading $download_url"
		return 1
	fi

	# $MD5 $release_tar_path > "$(get_version_directory $version)/$release_filename.md5"
	downloaded_tar_md5="$($MD5 $release_tar_path | read_md5)"
	remote_tar_md5="$(get_version_remote_md5 $version | read_md5)"

	if [[ "$downloaded_tar_md5" != "$remote_tar_md5" ]]; then
		rm $release_tar_path
		console_error "Downloaded $release_filename MD5 [$downloaded_tar_md5] does not match remote MD5 [$remote_tar_md5]"
		return 1
	fi

	tar -xf $release_tar_path -C "$(get_version_directory $version)"
	if [[ $? -ne 0 ]]; then
		console_error "Error extracting tar $release_tar_path"
		return 1
	fi

	chmod +x "$(get_version_binary_path $version)"
	if [[ $? -ne 0 ]]; then
		console_error "Error making $(get_version_binary_path $version) executable"
		return 1
	fi
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
}

# Main
set_os_specific_commands
verify_env

if [[ $1 = "update" ]]; then
    update $WARDEN_VERSION
    exit 0
fi

version="${1:-$WARDEN_VERSION}"

if [ ! -e "$(get_version_binary_path $version)" ]; then
    download_warden $version
    if [[ $? -ne 0 ]]; then
        exit $?
    fi
fi

exec "$(get_version_binary_path $version)"
