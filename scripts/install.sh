#!/usr/bin/env sh

get_shell_profile_path()
{
    shell=$(echo $SHELL | grep -Eo "\w+$")

    case $shell in
    "zsh")
        echo "$HOME/.zprofile"
        ;;
    "bash")
        echo "$HOME/.bash_profile"
        ;;
    esac
}

set_env_variables()
{
    cat >> "$(get_shell_profile_path)" <<- EOM
export WARDEN_VERSION="0.1.0-alpha.1"
export WARDEN_OS_ARCH="darwin-amd64"
export WARDEN_HOME="$HOME/.warden"
EOM

    export WARDEN_VERSION="0.1.0-alpha.1"
    export WARDEN_OS_ARCH="darwin-amd64"
    export WARDEN_HOME="$HOME/.warden"
}

create_warden_directories() 
{
    if [[ ! -d "$WARDEN_HOME" ]] || [[ ! -d "$WARDEN_HOME/bin" ]]
    then
        mkdir -p "$WARDEN_HOME/bin"
    fi
}

download_warden_script()
{
    warden_script_path="$WARDEN_HOME/bin/warden"
    curl -fsSL "https://raw.githubusercontent.com/NoFateLLC/warden-releases/master/scripts/warden.sh" > "$warden_script_path"
    chmod +x "$warden_script_path"
    exec "$warden_script_path"
}

set_env_variables
create_warden_directories
download_warden_script
