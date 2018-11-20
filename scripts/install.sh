#!/usr/bin/env bash

##################
# Globals
##################

# Process the inputs.  Must be processed before assigning globals
while (( $# > 0 )); do
    case $1 in
        -n )
            IRON_SETUP_REPO=${IRON_SETUP_REPO:-"iron-cli-nightly-repo"}
            shift
            version=$1
            ;;
        -f )
            IRON_SETUP_REPO=${IRON_SETUP_REPO:-"iron-cli-features-repo"}
            shift
            version=$1
            ;;
        * )
            version=$1
    esac
    shift
done

# This must be set first since $IRON_HOME is a dependency for all other functions
IRON_HOME="$HOME/.cott"

# The github org where the setup artifact can be found
IRON_SETUP_ORG=${IRON_SETUP_ORG:-"cott-io"}

# The github repo where the setup artifact can be found
IRON_SETUP_REPO=${IRON_SETUP_REPO:-"iron-cli-releases-repo"}

# This is the repo that hosts the version of iron to install (not setup)
IRON_ORG=${IRON_ORG:-${IRON_SETUP_ORG}}

# This is the repo that hosts the version of iron to install (not setup)
IRON_REPO=${IRON_REPO:-${IRON_SETUP_REPO}}

# The default repository that hosts the artifacts
IRON_SETUP_REPO_URL="https://github.com/${IRON_SETUP_ORG}/${IRON_SETUP_REPO}"

# The url of the api call for determining the latest artifact
IRON_SETUP_LATEST_URL=${IRON_SETUP_REPO_URL/https:\/\/github.com/https:\/\/api.github.com\/repos}/releases/latest

# The url of the api call for determining the latest artifact
IRON_SETUP_DOWNLOAD_URL=$IRON_SETUP_REPO_URL/releases/download

export IRON_ORG
export IRON_REPO
export IRON_SETUP_ORG
export IRON_SETUP_REPO

##################
# Utility functions
##################

# Defers contains the commands to run at exit
DEFERS=()
handler() {
    code=$?; eval "${DEFERS[*]}"; exit $code
}

# Defers a command to be invoked at exit
defer() {
    DEFERS+=( "$*;" )
    trap handler EXIT
}

# Logs an info level message to the console (and colors it green if available)
console_info() {
    if ! tput setaf &>/dev/null; then
        echo "$1"
    else
        echo "$(tput setaf 2)$1$(tput sgr0)"
    fi
}

# Logs an error level message to the console (and colors it red if available)
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


get_arch() {
    arch=$(uname -m)
    case $arch in
    "x86_64")
        echo "amd64"
        ;;
    "i386")
        echo "386"
        ;;
    "arm")
        echo "arm"
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

if [[ "$(get_os)" == 'linux' ]]; then
    SED_EXTENDED="sed -r"
    GREP_EXTENDED="grep -P"
    SHA512="sha512sum"
else
    SED_EXTENDED="sed -E"
    GREP_EXTENDED="grep -E"
    SHA512="shasum -a 512"
fi


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
    curl -fsSL $IRON_SETUP_LATEST_URL | $GREP_EXTENDED -o '"tag_name":.*?[^\\]\",' | $SED_EXTENDED 's/^ *//;s/.*: *"//;s/",?//'
}

get_release_url() {
    if [[ $# -ne 2 ]]; then
        console_error "get_release_url requires arguments: version, os_arch"
        return 1
    fi

    local version=$1
    local os_arch=$2
    echo "$IRON_SETUP_DOWNLOAD_URL/${version}/iron-${os_arch}-setup.zip"
}

get_release_sha512() {
    if [[ $# -ne 2 ]]; then
        console_error "get_release_sha512 requires arguments: version, os_arch"
        return 1
    fi

    local version=$1
    local os_arch=$2
    local sha512_url="$(get_release_url $version $os_arch).sha512"
    local sha512="$(curl -fsSL "$sha512_url")"
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        console_error "Error downloading $sha512_url"
        return 1
    fi
    echo $sha512
}

####################
# Download / Install
####################

install_iron() {
    if [[ ! $# -eq 2 ]]; then
        console_error "install_iron_version requires arguments: version and os_arch"
        return 1
    fi

    local version=$1
    local os_arch=$2
    console_info "Downloading and verifying launcher [$version] on [$os_arch]"

    local download_url="$(get_release_url $version $os_arch)"
    local target_dir="$IRON_HOME/downloads/$version"
    local target_zip="$target_dir/$(basename $download_url)"
    defer rm -r $target_dir

    if ! mkdir -p $target_dir; then
        console_error "Unable to make directory [$target_dir]"
        return 1
    fi

    curl -fsSL "$download_url" > $target_zip
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        console_error "Error downloading iron release [$download_url]"
        return 1
    fi

    local local_zip_sha512="$($SHA512 $target_zip | read_sha512)"
    local remote_zip_sha512="$(get_release_sha512 $version $os_arch | read_sha512)"
    if [[ "$local_zip_sha512" != "$remote_zip_sha512" ]]; then
        console_error "Downloaded hash [$local_zip_sha512] does not match remote hash [$remote_zip_sha512]"
        return 1
    fi

    unzip -o $target_zip -d "$target_dir" &> /dev/null
    if [[ $? -ne 0 ]]; then
        console_error "Error extracting zip [$target_zip]"
        return 1
    fi

    $target_dir/fe .setup
    if [[ $? -ne 0 ]]; then
        console_error "Error running setup"
        return 1
    fi
}


########
# Main #
########

if [[ "$version" != "" ]]; then
    version=$version
else
    version=$(get_latest_version)
fi

if ! install_iron "$version" "$(get_os_arch)"; then
    exit $?
fi
