#!/usr/bin/env sh

console_info() {
	if ! tput setaf &> /dev/null
	then
		echo "$1"
	else
		echo "$(tput setaf 2)$1$(tput sgr0)"
	fi
}

console_error() {
	if ! tput setaf &> /dev/null
	then
		echo "$1" 1>&2
	else
		echo "$(tput setaf 1)$1$(tput sgr0)" 1>&2
	fi
}

get_binary_directory()
{
    echo "$WARDEN_HOME/bin"
}

get_version_path()
{
    version=$1
    echo "$(get_binary_directory)/warden-$WARDEN_OS_ARCH-$version"
}

download_warden()
{
    version=$1
    console_info "Downloading warden version: [$version] platform: [$WARDEN_OS_ARCH]..."
    
    release_file="warden-$WARDEN_OS_ARCH.tar.gz"
    download_url="https://github.com/nofatellc/warden-releases/releases/download/$version/$release_file"

    curl -fsSL "$download_url" | tar -xzvO warden > "$(get_version_path $version)"
    if [[ ${PIPESTATUS[0]} -ne 0 ]]
    then
        echo "Error downloading $download_path"
        return 1
    fi
    chmod +x "$(get_version_path $version)"
}

# Main
if [[ -z "$WARDEN_HOME" ]]
then
    console_error "WARDEN_HOME not set..."
    exit 1
fi

if [[ -z "$WARDEN_OS_ARCH" ]]
then
    console_error "WARDEN_OS_ARCH not set..."
    exit 1
fi

version="${1:-$WARDEN_VERSION}"

if [[ -z "$version" ]]
then
    console_error "WARDEN_VERSION not set..."
    exit 1
fi

if [[ ! -d "$(get_binary_directory)" ]]
then
    mkdir "$(get_binary_directory)"
fi

if [ ! -e "$(get_version_path $version)" ]
then
    download_warden $version
fi

exec "$(get_version_path $version)"
