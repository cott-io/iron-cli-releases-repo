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
	default_warden_home="$HOME/.warden"
    env_shell="$(get_shell)"

	read -p "What version of warden do you want to install (WARDEN_VERSION)? [$latest_version] " warden_version
	warden_version=${warden_version:-$latest_version}
	read -p "Set WARDEN_OS_ARCH (i.e. darwin_x86_64, linux_i386) [$os_arch]: " warden_os_arch
	warden_os_arch=${warden_os_arch:-$os_arch}
	read -p "What do you want the warden home directory to be (WARDEN_HOME)? [$default_warden_home]: " warden_home
	warden_home=${warden_home:-$default_warden_home}
    read -p "What is your shell (i.e. bash, zsh)? [$env_shell] " shell
    shell=${shell:-$env_shell}

	mkdir -p $warden_home

	env_path="$warden_home/env.sh"

	cat >"$env_path" <<-EOM
export WARDEN_VERSION="$warden_version"
export WARDEN_OS_ARCH="$warden_os_arch"
export WARDEN_HOME="$warden_home"
export PATH="$PATH:$WARDEN_HOME/bin"
EOM

    source $env_path

    source_line="source $env_path"

	shell_rc_path=`get_shell_rc_path $shell`

    if [[ $? -ne 0 ]]; then
        console_error "Unable to add add to $shell rc file. Please add '$source_line' to your shell's rc file"
        return
    fi

	if grep -q "$source_line" $shell_rc_path; then
		return
	fi

	echo $source_line >> $shell_rc_path
}

create_warden_directories() {
	if [[ ! -d "$WARDEN_HOME" ]] || [[ ! -d "$WARDEN_HOME/bin" ]]; then
		mkdir -p "$WARDEN_HOME/bin"
	fi
}

download_warden_script() {
    mkdir -p "$WARDEN_HOME/bin"
	warden_script_path="$WARDEN_HOME/bin/warden"
	curl -fsSL "https://raw.githubusercontent.com/NoFateLLC/warden-releases/master/scripts/warden.sh" >"$warden_script_path"
	if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
		echo "Error downloading warden.sh"
		return 1
	fi
	chmod +x "$warden_script_path"
}

set_os_specific_commands
add_env

download_warden_script

console_info "Successfully installed warden! Please source your environment for changes to take effect (Start a new terminal session)."
