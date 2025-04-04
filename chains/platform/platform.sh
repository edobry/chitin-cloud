export CHI_CLOUD_PLATFORM_KNOWN="local aws gcp"
export CHI_CLOUD_PLATFORM_KNOWN_COMMANDS="check auth revoke id account"

function chiCloudListPlatforms() {
    echo "$CHI_CLOUD_PLATFORM_KNOWN" | splitOnSpaces
}

function chiCloudSetPlatform() {
    requireArgOptions "a platform name" "$1" "$CHI_CLOUD_PLATFORM_KNOWN" || return 1
    
    export CHI_CLOUD_PLATFORM_CURRENT="$1"
}

function chiCloudGetPlatform() {
    if [[ -z "$CHI_CLOUD_PLATFORM_CURRENT" ]]; then
        local defaultPlatform="$(chiConfigUserReadModule cloud platform default)"
        chiCloudSetPlatform "$defaultPlatform"
    fi

    echo "$CHI_CLOUD_PLATFORM_CURRENT"
}

export CHI_CLOUD_PLATFORM_CONFIG_FIELD="platforms"

function chiCloudGetPlatformConfigs() {
    chiModuleConfigReadVariablePath cloud:platform "$CHI_CLOUD_PLATFORM_CONFIG_FIELD"
}

function chiCloudGetPlatformConfig() {
    requireArg "a platform name" "$1" || return 1

    jsonReadPath "$(chiCloudGetPlatformConfigs)" "$1"
}

function chiCloudGetPlatformCommand() {
    requireArgOptions "a command name" "$1" "$CHI_CLOUD_PLATFORM_KNOWN_COMMANDS" || return 1

    local platform="$(chiCloudGetPlatform)"
    jsonReadPath "$(chiCloudGetPlatformConfig "$platform")" "$1"
}

function chiCloudPlatformCommand() {
    requireArg "a command name" "$1" || return 1

    chiCloudGetPlatformCommand "$1"
    [[ -z "$command" ]] && return 1

    "$command"
}

function chiCloudPlatformAuth() {
    chiCloudPlatformCommand auth
}

function chiCloudPlatformId() {
    chiCloudPlatformCommand id
}

function chiCloudPlatformAccount() {
    chiCloudPlatformCommand account
}

function chiCloudPlatformCheckAuth() {
    local checkCommand="$(chiCloudGetPlatformCommand check)"
    [[ "$checkCommand" == "false" ]] && return 0

    if ! "$checkCommand" 2>&1; then
        chiLogError "unauthenticated!" cloud platform
        return 1
    fi
}

# checks if you're authenticated, or fails. meant to be used as a failfast
function chiCloudPlatformCheckAuthAndFail() {
    if ! chiCloudPlatformCheckAuth; then
        chiLogError "authenticate with the $CHI_CLOUD_PLATFORM_CURRENT platform before rerunning" cloud platform
        return 1
    fi
}
