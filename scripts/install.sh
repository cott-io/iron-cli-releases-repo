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

get_os_arch() {
	echo "$(get_os)_$(get_arch)"
}

get_latest_version() {
	curl -fsSL "$GITHUB_API_RELEASES_REPO_URL/releases/latest" | $GREP_EXTENDED -o '"tag_name":.*?[^\\]\",' | $SED_EXTENDED 's/^ *//;s/.*: *"//;s/",?//'
}

add_env() {
	latest_version="$(get_latest_version)"
	os_arch="$(get_os_arch)"
	warden_home="$HOME/.warden"
    shell="$(get_shell)"

	mkdir -p $warden_home

	env_path="$warden_home/env.sh"

	cat > "$env_path" <<-EOM
export WARDEN_VERSION="$warden_version"
export WARDEN_OS_ARCH="$warden_os_arch"
export WARDEN_HOME="$warden_home"
export PATH="$PATH:\$WARDEN_HOME/bin"
EOM

    source $env_path

    source_line="source $env_path"

	shell_rc_path=$(get_shell_rc_path $shell)

    if [[ $? -ne 0 ]]; then
        console_error "Unable to add add to $shell rc file. Please add '$source_line' to your shell's rc file"
        return 1
    fi

	if ! grep -q "$source_line" $shell_rc_path; then
		echo $source_line >> $shell_rc_path
	fi

    cat <<-EOM
Set the following in $WARDEN_HOME/env.sh:

export WARDEN_VERSION="$warden_version"
export WARDEN_OS_ARCH="$warden_os_arch"
export WARDEN_HOME="$warden_home"
export PATH="$PATH:$WARDEN_HOME/bin"

and added the following to $shell_rc_path:

$source_line

EOM
}

download_warden_script() {
    mkdir -p "$WARDEN_HOME/bin"
	warden_script_path="$WARDEN_HOME/bin/warden"
	curl -fsSL "https://raw.githubusercontent.com/NoFateLLC/warden-releases/master/scripts/warden.sh" >"$warden_script_path"
	if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
		console_error "Error downloading warden.sh"
		return 1
	fi
	chmod +x "$warden_script_path"
}

download_warden_update_script() {
    mkdir -p "$WARDEN_HOME/bin"
	warden_update_script_path="$WARDEN_HOME/bin/warden-update"
	curl -fsSL "https://raw.githubusercontent.com/NoFateLLC/warden-releases/master/scripts/warden-update.sh" >"$warden_update_script_path"
	if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
		console_error "Error downloading warden-update.sh"
		return 1
	fi
	chmod +x "$warden_update_script_path"
}

set_os_specific_commands

if ! add_env; then
    exit 1
fi

if download_warden_script && download_warden_update_script; then
    console_info "Successfully installed warden! Please source your environment for changes to take effect (Start a new terminal session)."
fi
