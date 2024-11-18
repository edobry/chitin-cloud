# prints out the local Helm repository configuration
function helmRepoReadConfig() {
    eval $(helm env | grep HELM_REPOSITORY_CONFIG); cat "$HELM_REPOSITORY_CONFIG" | prettyYaml
}

# gets the local Helm registry configuration
function helmRegistryGetConfig() {
    eval $(helm env | grep HELM_REGISTRY_CONFIG); cat "$HELM_REGISTRY_CONFIG" | jq -c
}

# prints out the local Helm registry configuration
function helmRegistryReadConfig() {
    helmRegistryGetConfig | prettyYaml
}

# checks whether a given Helm repository is configured
# args: repo name
function helmRepoCheckConfigured() {
    requireArg "a repo" "$1" || return 1

    helm repo list -o json 2>/dev/null | jq -re --arg repo "$1" \
        '.[].name | select(.==$repo)' >/dev/null
}

# checks whether a given Helm registry is configured
# args: registry name
function helmRegistryCheckConfigured() {
    requireArg "a registry" "$1" || return 1

    helmRegistryGetConfig | jq -re --arg repo "$1/" \
        '.auths | has($repo)' >/dev/null
}

# configures the Artifactory Helm repository
# args: artifactory username, artifactory password
function helmRepoConfigure() {
    requireArg "a repository name" "$1" || return 1
    requireArg "a repository url" "$2" || return 1
    requireArg "a username" "$3" || return 1
    requireArg "a password" "$4" || return 1

    local name="$1"
    local url="$2"
    local username="$3"
    local password="$4"

    # load helm envvars into session
    eval $(helm env)

    mkdir -p "$HELM_REPOSITORY_CACHE"
    if helmRepoCheckConfigured "$name";
    then
        echo "repo '$name' already exists, removing first..."
        helm repo remove "$name"
    fi

    echo "Configuring repo..."
    helm repo add "$name" "$url" \
        --username "$username" --password "$password"
    helm repo update
}

function helmRegistryConfigure() {
    requireArg "a registry url" "$1" || return 1
    requireArg "a username" "$2" || return 1
    requireArg "a password" "$3" || return 1

    local url="$1"

    # load helm envvars into session
    eval $(helm env)

    mkdir -p "$(dirname "$HELM_REPOSITORY_CONFIG")"
    if helmRegistryCheckConfigured "$url";
    then
        echo "registry '$name' already exists, removing first..."
        helm registry logout "$url"
    fi

    echo "Configuring registry..."
    echo "$3" | helm registry login "$url" -u "$2" --password-stdin
}

# prints a JSON object containing the locally-configured credentials for the given repository
# args: repo name
function helmRepoGetCredentials() {
    requireArg 'a repo name' "$1" || return 1

    helmRepoReadConfig | yamlToJson | jq -cr --arg repo "$1" \
        '.repositories[] | select(.name == $repo) | { username, password }'
}

# gets the latest version of a given Helm chart
# args: chart path
function helmChartGetLatestRemoteVersion() {
    if [[ "$1" == "oci"* ]]; then
        [[ "$1" == "oci" ]] && shift
        
        helmChartGetLatestRegistryVersion $*
    else
        requireArg "a chart identifier" "$1" || return 1

        helmChartGetLatestRepoVersion $*
    fi
}

# gets the latest version of a given Helm chart
# args: chart path
function helmChartGetLatestRepoVersion() {
    requireArg "a chart path" $1 || return 1

    helm repo update > /dev/null
    local helmResponse=$(helm search repo "$1" --output json)
    [[ $helmResponse = "[]" ]] && return 1

    jsonRead "$helmResponse" '.[] | .version'
}

function helmChartGetLatestRegistryVersion() {
    local registryDomain
    local chartNamespace
    local chartName

    if [[ "$1" == "oci"* ]]; then
        local chartUrl=$(echo "${1#oci://}")
        registryDomain=$(echo "$chartUrl" | cut -d'/' -f1)
        chartNamespace=$(echo "$chartUrl" | cut -d'/' -f2)
        chartName="$(echo "$chartUrl" | cut -d'/' -f3)/$(echo "$chartUrl" | cut -d'/' -f4)"
    else
        requireArg "a registry domain" "$1" || return 1
        requireArg "a namespace" "$2" || return 1
        requireArg "a chart name" "$3" || return 1

        registryDomain="$1"
        chartNamespace="$2"
        chartName="$3"
    fi

    dockerCurlListTags "$registryDomain" "$chartNamespace" "$chartName" |
        jq -r '[
            .manifest[] | { timeUploadedMs, tag } 
                | select(.tag | length > 0)
                | select(.tag[] | contains("-") | not)
        ] | sort_by(.timeUploadedMs) | reverse[0] | .tag[0]'
}

# checks whether the given version of the given Helm chart exists
# args: chart path, chart version
function helmChartCheckRemoteVersion() {
    if [[ "$1" == "oci"* ]]; then
        [[ "$1" == "oci" ]] && shift
        
        helmChartCheckRegistryVersion $@
    else
        requireArg "a chart identifier" "$1" || return 1

        helmChartCheckRepoVersion $*
    fi
}

# checks whether the given version of the given Helm chart exists
# args: chart path, chart version
function helmChartCheckRepoVersion() {
    requireArg "a chart path" "$1" || return 1
    requireArg "a version" "$2" || return 1

    helm repo update > /dev/null
    local helmResponse=$(helm search repo "$1" --version "$2" --output json)
    [[ $helmResponse != "[]" ]]
}

# checks whether the given version of the given Helm chart exists
# args: chart path, chart version
function helmChartCheckRegistryVersion() {
    requireArg "a registry domain" "$1" || return 1
    requireArg "a namespace" "$2" || return 1
    requireArg "a chart path" "$3" || return 1
    requireArg "a version" "$4" || return 1

    ociRepoGetArtifactManifestConfig "$1" "$2" "$3" "$4" &>/dev/null
}

# gets the version of a local Helm chart
# args: chart path
function helmChartGetLocalVersion() {
    requireArg "a chart path" $1 || return 1

    local showChartOutput
    showChartOutput=$(helm show chart $1 2>&1)
    # check if there is a chart at this path
    [[ $? -ne 0 ]] && return 1

    yq e '.version' - <<< $showChartOutput
}

# gets the latest version of a given Helm chart
# args: chart source, chart path
function helmChartGetLatestVersion() {
    requireArgOptions "a chart source" "$1" "remote" "local" || return 1
    requireArg "a chart identifier" "$2" || return 1

    local source="$1"; shift

    local chartVersion;
    if [[ "$source" = "remote" ]]; then
        helmChartGetLatestRemoteVersion $*
    elif [[ "$source" = "local" ]]; then
        helmChartGetLocalVersion $*
    fi
}

# checks the version of a given Helm chart against a desired version
# args: chart source, chart path, chart version
function helmChartCheckVersion() {
    requireArgOptions "a chart source" "$1" "remote" "local" || return 1
    requireArg "a chart path" $2 || return 1
    requireArg "a version" $3 || return 1

    local source="$1"
    local chartPath="$2"
    local version="$3"

    local chartVersion
    if [[ $source = "remote" ]]; then
        helmChartCheckRemoteVersion "$chartPath" $version
    elif [[ $source = "local" ]]; then
        [[ $version = $(helmChartGetLocalVersion "$chartPath") ]]
    fi
}

function kustomizeUpdateChartVersionToLatest() {
    requireYamlArg "kustomization file path" "$1" || return 1

    local chart=$(yamlReadFile kustomization.yaml '.helmCharts[0] | { name, repo, version }')

    local chartName=$(jsonReadPath "$chart" name)
    local chartRepo=$(jsonReadPath "$chart" repo)

    local latestVersion="$(helmChartGetLatestVersion remote "$chartRepo/$chartName")"

    yamlFileSetFieldWrite "$1" "$latestVersion" helmCharts 0 version
}
