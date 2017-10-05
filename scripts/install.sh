#!/usr/bin/env bash

###########
# Constants
###########

GITHUB_RELEASES_DOWNLOAD_URL="https://github.com/warden-pub/warden-releases/releases/download"
WARDEN_ADDR=${WARDEN_ADDR:-"alpha.warden.pub:143"}

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

get_shell() {
	echo $SHELL | $GREP_EXTENDED -o "\w+$"
}

get_shell_rc_path() {
	shell=$1

	case $shell in
	"zsh")
		echo "$HOME/.zshrc"
		;;
	"bash")
		echo "$HOME/.bashrc"
		;;
	*)
		return 1
		;;
	esac
}

get_arch() {
	arch=$(uname -m)
	case $arch in
	"x86_64")
		echo "amd64"
		;;
	"i386")
		echo "386"
		;;
	*)
		console_error "Arch [$arch] not supported"
		return 1
		;;
	esac
}

get_os() {
	os=$(uname -s)
	case $os in
	"Darwin")
		echo "darwin"
		;;
	"Linux")
		echo "linux"
		;;
	*)
		console_error "OS [$os] not supported"
		return 1
		;;
	esac
}

get_os_arch() {
	echo "$(get_os)_$(get_arch)"
}

###########
# Utilities
###########

read_md5() {
    $GREP_EXTENDED -o "^\w+"
}

##################
# Github Functions
##################

get_latest_version() {
	curl -fsSL "https://api.github.com/repos/warden-pub/warden-releases/releases/latest" | $GREP_EXTENDED -o '"tag_name":.*?[^\\]\",' | $SED_EXTENDED 's/^ *//;s/.*: *"//;s/",?//'
}

get_release_filename() {
	if [[ $# -ne 1 ]]; then
		console_error "get_release_filename requires arguments: os_arch"
		return 1
	fi

	local os_arch=$1

    echo "warden-$os_arch.tar.gz"
}

get_version_release_url() {
	if [[ $# -ne 2 ]]; then
		console_error "get_version_release_url requires arguments: version, os_arch"
		return 1
	fi

    local version=$1
	local os_arch=$2

    local release_filename="$(get_release_filename $os_arch)"
    echo "$GITHUB_RELEASES_DOWNLOAD_URL/$version/$release_filename"
}

get_version_remote_md5() {
	if [[ $# -ne 2 ]]; then
		console_error "get_version_remote_md5 requires arguments: version, os_arch"
		return 1
	fi

    local version=$1
	local os_arch=$2

    local md5_url="$(get_version_release_url $version $os_arch).md5"

    local md5="$(curl -fsSL "$md5_url")"
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        console_error "Error downloading $md5_url"
        return 1
    fi

    echo $md5
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

####################
# Download / Install
####################

download_warden_script() {
	mkdir -p "$WARDEN_HOME/bin"
	local warden_script_path="$WARDEN_HOME/bin/warden"
	curl -fsSL "https://raw.githubusercontent.com/NoFateLLC/warden-releases/master/scripts/warden.sh" > "$warden_script_path"
	if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
		console_error "Error downloading warden.sh"
		return 1
	fi
	chmod +x "$warden_script_path"
}

install_warden_version() {
	if [[ ! $# -eq 2 ]]; then
		console_error "install_warden_version requires arguments: version and os_arch"
		return 1
	fi

    local version=$1
	local os_arch=$2
    
    console_info "Downloading warden version: [$version] platform: [$os_arch]..."

    local release_filename="$(get_release_filename $os_arch)"
    local download_url="$(get_version_release_url $version $os_arch)"

    mkdir -p "$(get_version_directory $version)"

    local release_tar_path="$(get_version_directory $version)/$release_filename"

    curl -fsSL "$download_url" > $release_tar_path
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        console_error "Error downloading $download_url"
        return 1
    fi

    # $MD5 $release_tar_path > "$(get_version_directory $version)/$release_filename.md5"
    local downloaded_tar_md5="$($MD5 $release_tar_path | read_md5)"
    local remote_tar_md5="$(get_version_remote_md5 $version $os_arch | read_md5)"

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

install_version_env() {
	if [[ ! $# -eq 2 ]]; then
		console_error "install_version_env requires arguments: version, os_arch"
		return 1
	fi

	local version=$1
	local os_arch=$2

	mkdir -p "$(get_version_directory $version)"

	local version_env_path="$(get_version_directory $version)/env.sh"

	cat > "$version_env_path" <<-EOM
export WARDEN_VERSION="$version"
export WARDEN_OS_ARCH="$os_arch"
export WARDEN_HOME="$WARDEN_HOME"
export WARDEN_AUTO_UPDATE_INTERVAL=3600  # In seconds (1 hour)
WARDEN_PATH="$WARDEN_HOME/bin"
if [[ "\$PATH" != *"\$WARDEN_PATH"* ]]; then
    export PATH="\$PATH:\$WARDEN_PATH"
fi
EOM

	cat <<EOM
Set the following in $version_env_path:

$(cat $version_env_path)

EOM
}

install_root_env() {
	if [[ ! $# -eq 1 ]]; then
		console_error "install_root_env requires arguments: version"
		return 1
	fi

	local version=$1

	local version_env_path="$(get_version_directory $version)/env.sh"

	local env_path="$(get_env_path)"
	cat > "$env_path" <<-EOM
source $version_env_path
EOM
	
	local source_line="source $env_path"
	local shell="$(get_shell)"
	local shell_rc_path=$(get_shell_rc_path $shell)

	if [[ $? -ne 0 ]]; then
		console_error "Unable to add add to $shell rc file. Please add '$source_line' to your shell's rc file"
		return 1
	fi

	read -r -d '' add_rc <<EOM

# Added by warden
$source_line
EOM

	if ! grep -q "$add_rc" $shell_rc_path; then
		echo "$add_rc" >> $shell_rc_path
	fi

	cat <<EOM

Set the following in $env_path:

$(cat $env_path)

Added the following to $shell_rc_path:

$add_rc

EOM
}

########
# Main #
########

set_os_specific_commands

version=${1:-$(get_latest_version)}
last_update_check=$(date +"%s")

# This must be set first since $WARDEN_HOME is a dependency for all other functions
WARDEN_HOME="$HOME/.warden"

os_arch="$(get_os_arch)"

if ! install_version_env $version $os_arch; then
	exit $?
fi

if ! install_warden_version $version $os_arch; then
	exit $?
fi

if ! download_warden_script $version; then
	exit $?
fi

if ! install_root_env $version; then
	exit $?
fi

console_info "Setting service address [$WARDEN_ADDR]"
"$(get_version_binary_path $version)" config set --remote $WARDEN_ADDR

console_info "Successfully installed warden $version! Please source your environment for changes to take effect (Start a new terminal session)."
