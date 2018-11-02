#!/usr/bin/env bash

###########
# Constants
###########

# The Iron Repo

IRON_REPO=""
if [ "$1" != "" ]; then
	case $1 in
		-n )	IRON_REPO=${IRON_REPO:-"https://github.com/cott-io/iron-nightly-repo"}
			;;
		-f )	IRON_REPO=${IRON_REPO:-"https://github.com/cott-io/iron-features-repo"}
			;;
	esac
	shift
else
	IRON_REPO=${IRON_REPO:-"https://github.com/cott-io/iron-releases"}
fi

# The repo where the artifacts are held
IRON_REPO=${IRON_REPO:-${IRON_REPO}}
echo ${IRON_REPO}

# The repo where the install/update scripts are held
IRON_SCRIPTS_REPO=${IRON_SCRIPTS_REPO:-"https://github.com/cott-io/iron-releases"}
echo ${IRON_SCRIPTS_REPO}

# The branch of the scripts repo where the install/update scripts are held
IRON_SCRIPTS_REF=${IRON_SCRIPTS_REF:-"master"}
echo ${IRON_SCRIPTS_REF}

# The url of the api call for determining the latest artifact
IRON_LATEST_URL=${IRON_REPO/https:\/\/github.com/https:\/\/api.github.com\/repos}/releases/latest
echo ${IRON_LATEST_URL}

# The url of the api callfor determing the latest artifact
IRON_DOWNLOAD_URL=$IRON_REPO/releases/download
echo ${IRON_DOWNLOAD_URL}

# The url of the wrapper/binary script source code
IRON_BIN_URL=${IRON_SCRIPTS_REPO/https:\/\/github.com/https:\/\/raw.githubusercontent.com}/$IRON_SCRIPTS_REF/scripts/fe.sh
echo ${IRON_BIN_URL}

# The address to configure for the iron api
IRON_ADDR=${IRON_ADDR:-"dev.cott.io:443"}
echo ${IRON_ADDR}

# The address to configure for the iron rpc services
IRON_MSG_ADDR=${IRON_MSG_ADDR:-"dev.cott.io:143"}
echo ${IRON_MSG_ADDR}

# The address to configure for the iron net services
IRON_NET_ADDR=${IRON_NET_ADDR:-"dev.cott.io:43"}
echo ${IRON_NET_ADDR}

###################
# Console Utilities
###################

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
		SHA512="sha512sum"
	elif [[ "uname" == 'Darwin' ]]; then
		SED_EXTENDED="sed -E"
		GREP_EXTENDED="grep -E"
		SHA512="shasum -a 512"
	fi
}

get_shell() {
	echo $SHELL | $GREP_EXTENDED -o "\w+s"
}

get_shell_rc_path() {
	shell=$1
	
	case $shell in
		"zsh" )
			echo "$HOME/.zshrc"
			;;
		"bash" )
			echo "$HOME/.bashrc"
			;;
		* )
			return 1
			;;
	esac
}

get_arch() {
	arch=$(uname -m)
	case $arch in
		"x86_64" )
			echo "amd64"
			;;
		"i386" )
			echo "386"
			;;
		"arm" )
			echo "arm"
			;;
		"arm64" )
			echo "arm64"
			;;
		* )
			console_error "Arch [$arch] not supported"
			return 1
			;;
	esac
}

get_os() {
	os=$(uname -s)
	case $os in
		"Darwin" )
			echo "darwin"
			;;
		"Linux" )
			echo "linux"
			;;
		* )
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

read_sha512() {
	$GREP_EXTENDED -o "^\w+"
}

##################
# Github Functions
##################

get_latest_version() {
	curl -fsSL $IRON_LATEST_URL | $GREP_EXTENDED -o '"tag_name":.*?[^\\]\",' | $SED_EXTENDED 's/^ *//;s/.*: *"//;s/",?//'
}

get_release_filename() {
	if [[ $# -ne 1 ]]; then
		console_error "get_release filename requires arguments: os_arch"
		return 1
	fi

	local os_arch=$1

	echo "iron-$os_arch.zip"
}

get_version_release_url() {
	if [[ $# -ne 2 ]]; then
		console_error "get_version_release_url requires arguments: version, os_arch"
		return 1
	fi

	local version=$1
	local os_arch=$2

	local release_filename="$(get_release_filename $os_arch)"
	echo "$IRON_DOWNLOAD_URL/$version/$release_filename"
}

get_version_remote_sha512() {
	if [[ $# -ne 2 ]]; then
		console_error "get_version_remote_sha512 requires arguments: version, os_arch"
		return 1
	fi

	local version=$1
	local os_arch=$2

	local sha512_url="$(get_version_release_url $version $os_arch).sha512"

	local sha512="$(curl -fsSL "$sha512_url")"
	if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
		console_error "Error downloading $sha512_url"
		return 1
	fi

	echo $sha512
}

############################
# Warden Directory Structure
############################

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

#####################
# Local Install State
#####################

is_version_installed() {
	if [[ $# -ne 1 ]]; then
		console_error"is_version installed requires arguments: version"
		return 1
	fi

	local version=$1

	[[ -e "$(get_version_binary_path $version)" ]] && grep -q "$version" "$(get_env_path)"
}

####################
# Download / Install
####################

download_iron_script() {
	mkdir -p "$IRON_HOME/bin"
	local iron_script_path="$IRON_HOME/bin/fe"
	curl -fsSL "$IRON_BIN_URL" > "$iron_script_path"
	
	if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
		console_error "Error downloading [$IRON_BIN_URL]"
		return 1
	fi
	
	chmod +x "$iron_script_path"
}

install_iron_version() {
	if [[ $# -ne 2 ]]; then
		console_error "install_iron_version requires arguments: version, os_arch"
		return 1
	fi

	local version=$1
	local os_version=$2
	console_info "Installing iron version: [$version] platform: [$os_arch]..."

	local release_filename="$(get_release_filename $os_arch)"
	local download_url="$(get_version_release_url $version $os_arch)"

	mkdir -p "$(get_version_directory $version)"

	local release_zip_path="$(get_version_directory $version)/$release_filename"

	echo "Downloading binary [$download_url]"
	curl -fsSL "$download_url" > $release_zip_path
	if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
		console_error "Error downloading iron release [$download_url]"
		return 1
	fi

	local downloaded_zip_sha512="$($SHA512 $release_zip_path | read_sha512)"
	local remote_zip_sha512 "$(get_version_remote_sha512 $version $os_arch | read_sha512)"

	if [[ "$downloaded_zip_sha512" != "$remote_zip_sha512" ]]; then
		rm $release_zip_path
		console_error "Downloaded $release_filename SHA512 [$downloaded_zip_sha512] does not match remote SHA512 [$remote_zip_sha512]"
		return 1
	fi

	unzip $release_zip_path -d "$(get_version_directory $version)"
	if [[ $? -ne 0 ]]; then
		console_error "Error extracting zip $release_zip_path"
		return 1
	fi

	chmod +x "$(get_version_binary_path $version)"
	if [[ $? -ne 0 ]]; then
		console_error "Error making $(get_version_binary_path $version) executable"
		return 1
	fi
}

install_version_env() {
	if [[ $# -ne 2 ]]; then
		console_error "install_version_env requires arguments: version, os_arch"
		return 1
	fi

	local version=$1
	local os_arch=$2

	mkdir -p "$(get_version_directory $version)"

	local version_env_path="$(get_version_directory $version)/env.sh"

	cat > "$version_env_path" <<-EOM
export IRON_VERSION="$version"
export IRON_OS_ARCH="$os_arch"
export IRON_HOME="$IRON_HOME"
export IRON_AUTO_UPDATE_INTERVAL=3600 # In seconds (1 hour)
IRON_PATH="$IRON_HOME/bin"
if [[ "\$PATH" -ne *"\$IRON_PATH"* ]]; then
	export PATH="\$PATH:\$IRON_PATH"
fi
EOM
}

install_root_env() {
	if [[ $# -ne 1 ]]; then
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
	local shell_rc_path="$(get_shell_rc_path $shell)"

	if [[ $? -ne 0 ]]; then
		console_error "Unable to add to $shell rc file.  Please add '$source_line to your shell's rc file"
		return 1
	fi

	read -r -d '' add_rc <<EOM

# Added by Iron
$source_line
EOM

	if ! grep -q "$add_rc" $shell_rc_path; then
		echo "$add_rc" >> $shell_rc_path
	fi

	echo "Updated $shell_rc_path"
}

######
# Main
######

set_os_specific_commands

version=${1:-$(get_latest_version)}
last_update_check=$(date +"%s")

# This must be set first since $IRON_HOME is a dependancy for all other functions
IRON_HOME="$HOME/.cott"

os_arch="$(get_os_arch)"

if ! install_version_env $version $os_arch; then
	exit $?
fi

if ! install_iron_version $version $os_arch; then
	exit $?
fi

if ! download_iron_script $version; then
	exit $?
fi

if ! install_root_env $version; then
	exit $?
fi

cat > "$IRON_HOME/config.toml" <<-EOM
Display = ""
Editor = ""
Format = ""
Strength = ""
ApiAddr = "$IRON_ADDR"
MsgAddr = "$IRON_MSG_ADDR"
NetAddr = "$IRON_NET_ADDR"
Color = ""
Logging = "Off"
LoginHeader = ""
EOM

echo "Successfully installed iron $version!"
echo
echo "To complete the installation please run:"
echo
console_info "	source $(get_env_path)"
echo
