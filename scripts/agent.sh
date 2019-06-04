
#####################
# PREFLIGHT CHECKS
#####################

if ! command -v curl > /dev/null; then
    echo "Curl not installed on agent host" >&2
    exit 1
fi
if ! command -v unzip > /dev/null; then
    echo "Unzip not installed on agent host" >&2
    exit 1
fi
if ! command -v systemctl > /dev/null; then
    echo "Systemd is not installed on agent host" >&2
    exit 1
fi

if [[ $(uname -s) != "Linux" ]]; then
    echo "Agent installer only supported on Linux" >&2
    exit 1
fi

if [[ $(uname -m) != "x86_64" ]]; then
    echo "Agent installer only supported on 64-bit machines" >&2
    exit 1
fi

if [[ $1 == "" ]]; then
    echo "Must supply a provision token. To obtain: $ fe agent gentoken" >&2
    exit 1
fi


#####################
# UTILITY FUNCTIONS
#####################

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

curl() {
    command curl -fsSL "$@"
}

sed() {
    command sed -r "$@"
}

grep() {
    command grep -P "$@"
}

shasum() {
    command sha512sum "$@"
}

#####################
# GLOBAL VARS
#####################

# The addresse of the iron api services
IRON_API_ADDR=${IRON_API_ADDR:-dev.cott.io:443}

# The addresse of the iron networking services
IRON_NET_ADDR=${IRON_NET_ADDR:-dev.cott.io:43}

# Determine the artifact url
if [[ -z $IRON_DOWNLOAD_URL ]]; then

    # The github org where the setup artifact can be found
    IRON_ORG=${IRON_ORG:-"cott-io"}

    # The github repo where the setup artifact can be found
    IRON_REPO=${IRON_REPO:-"iron-cli-releases-repo"}

    # The default repository that hosts the artifacts
    IRON_REPO_URL="https://github.com/$IRON_ORG/$IRON_REPO"

    # Determine the version to install if we don't already have one
    if [[ -z $IRON_VERSION ]]; then
        IRON_VERSION=$(curl ${IRON_REPO_URL/https:\/\/github.com/https:\/\/api.github.com\/repos}/releases/latest \
            | grep -o '"tag_name":.*?[^\\]\",' \
            | sed 's/^ *//;s/.*: *"//;s/",?//')
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            echo "Error determining iron version" >&2
            exit 1
        fi
    fi

    # The core artifact url
    IRON_DOWNLOAD_URL=$IRON_REPO_URL/releases/download/$IRON_VERSION/iron-linux_amd64-min.zip
fi

# The user under which to install the agent
AGENT_USER=${AGENT_USER:-"iron"}

echo "* Creating agent user account [$AGENT_USER]"
if ! id -u $AGENT_USER > /dev/null; then
    if ! sudo useradd $AGENT_USER > /dev/null; then
        echo "Could not add '$AGENT_USER' user" >&2
        exit 1
    fi
fi

echo "* Granting sudo access"
AGENT_GROUPS=( sudo wheel )
for group in "${AGENT_GROUPS[@]}"; do
    if getent group "$group" &> /dev/null; then
        if ! id -nG $AGENT_USER | grep -wq "$group"; then
            sudo usermod $AGENT_USER -aG "$group"
        fi
    fi
done

AGENT_HOME=$(eval "echo ~$AGENT_USER")
echo "* Setting up agent home [$AGENT_HOME]"

if ! sudo mkdir -p $AGENT_HOME/.cott; then
    echo "Failed to make user home directory" >&2
    exit 1
fi

if ! sudo chown -R $AGENT_USER:$AGENT_USER $AGENT_HOME; then
    echo "Failed to update user directory permissions" >&2
    exit 1
fi

echo "* Installing agent binary [$(basename $IRON_DOWNLOAD_URL)]"

TMP_ZIP_FILE=iron-agent.zip
if ! curl $IRON_DOWNLOAD_URL > $TMP_ZIP_FILE 2> /dev/null; then
    echo "Failed to download agent binary [$IRON_DOWNLOAD_URL]" >&2
    exit 1
fi
defer "rm $TMP_ZIP_FILE"

if [[ $(shasum $TMP_ZIP_FILE | grep -o '^\w+') != $(curl $IRON_DOWNLOAD_URL.sha512 | grep -o '^\w+' ) ]]; then
    echo "Failed to verify checksum of downloaded zip file" >&2
    exit 1
fi

if ! sudo unzip -o $TMP_ZIP_FILE -d /usr/bin &> /dev/null; then
    echo "Failed to install agent binary" >&2
    exit 1
fi

if ! sudo -u $AGENT_USER fe config set --api-addr $IRON_API_ADDR > /dev/null; then
    echo "Error updating iron config" >&2
    exit 1
fi

if ! sudo -u $AGENT_USER fe config set --net-addr $IRON_NET_ADDR > /dev/null; then
    echo "Error updating iron config" >&2
    exit 1
fi

AGENT_OPTS=()
if [[ "$AGENT_ADDR" != "" ]]; then
    AGENT_OPTS+=( "--remote-addr" "$AGENT_ADDR" )
fi

if [[ "$AGENT_NAME" != "" ]]; then
    AGENT_OPTS+=( "--name" "$AGENT_NAME" )
fi

echo "* Provisioning agent"
if ! sudo -u $AGENT_USER fe agent provision $1 ${AGENT_OPTS[@]}; then
    echo "Error provisioning agent" >&2
    exit 1
fi

echo "* Installing [iron-agent] systemd service"
if ! sudo mkdir -p /etc/systemd/system; then
    echo "Error initializing systemd environment" >&2
    exit 1
fi

sudo tee /etc/systemd/system/iron-agent.service > /dev/null <<-EOF
[Unit]
Description="Iron Agent"
Documentation=https://dev.cott.io
Requires=network-online.target
After=network-online.target

[Service]
User=$AGENT_USER
Group=$AGENT_USER
ExecStart=/usr/bin/fe agent start
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

if ! sudo systemctl daemon-reload; then
    echo "Unable to reload systemd units" >&2
    exit 1
fi

if ! sudo systemctl restart iron-agent; then
    echo "Error starting the agent.  Manully install using systemd: systemctl iron-agent start" >&2
    exit 1
fi

echo "* Successfully installed agent"
exit 0
