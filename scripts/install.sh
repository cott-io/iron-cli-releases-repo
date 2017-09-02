#!/usr/bin/env sh

set_env_variables()
{
    export WARDEN_VERSION="0.1.0-alpha.1"
    export WARDEN_OS_ARCH="darwin-amd64"
    if [[ -z "$WARDEN_HOME" ]]
        export WARDEN_HOME="$HOME/.warden"
    fi
}

create_warden_home() 
{
    if [ ! -d "$WARDEN_HOME" ]; then
        mkdir -p $WARDEN_HOME
    fi
}

download_warden_script()
{
    curl -L -o "$WARDEN_HOME"
}

set_env_variables
create_warden_home
