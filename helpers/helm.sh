# prints out the local Helm repository configuration
function helmRepoReadConfig() {
    eval $(helm env | grep HELM_REPOSITORY_CONFIG); cat $HELM_REPOSITORY_CONFIG | prettyYaml
}

# checks whether a given Helm repository is configured
# args: repo name
function helmRepoCheckConfigured() {
    requireArg "a repo" "$1" || return 1

    helm repo list -o json 2>/dev/null | jq -re --arg repo "$1" \
        '.[].name | select(.==$repo)' >/dev/null
}

# configures the Artifactory Helm repository
# args: artifactory username, artifactory password
function helmRepoConfigureArtifactory() {
	local username=$([[ ! -z "$1" ]] && echo "$1" || artifactoryGetUsername)
	local password=$([[ ! -z "$2" ]] && echo "$2" || artifactoryGetPassword)

    # load helm envvars into session
    eval $(helm env)

    mkdir -p "$HELM_HOME/.cache/helm/repository/"
    if helmRepoCheckConfigured $CA_ARTIFACTORY_DOMAIN;
    then
        echo "Artifactory repo already exists, removing first..."
        helm repo remove $CA_ARTIFACTORY_DOMAIN
    fi

    echo "Configuring Artifactory repo..."
    helm repo add $CA_ARTIFACTORY_DOMAIN $CA_ARTIFACTORY_HELM_REPO \
        --username ${username} --password ${password}
    helm repo update
}

# prints a JSON object containing the locally-configured credentials for the given repository
# args: repo name
function helmRepoGetCredentials() {
    requireArg 'a repo name' "$1" || return 1

    helmRepoReadConfig | yamlToJson | jq -cr --arg repo "$1" \
        '.repositories[] | select(.name == $repo) | { username, password }'
}

# prints a JSON object containing the locally-configured Artifactory credentials
function helmRepoGetArtifactoryCredentials() {
    helmRepoGetCredentials $CA_ARTIFACTORY_DOMAIN
}


# gets the latest version of a given Helm chart
# args: chart path
function helmChartGetLatestRemoteVersion() {
    requireArg "a chart path" $1 || return 1

    helm repo update > /dev/null
    local helmResponse=$(helm search repo $1 --output json)
    [[ $helmResponse = "[]" ]] && return 1

    jsonRead "$helmResponse" '.[] | .version'
}

# checks whether the given version of the given Helm chart exists
# args: chart path, chart version
function helmChartCheckRemoteVersion() {
    requireArg "a chart path" $1 || return 1
    requireArg "a version" $2 || return 1

    helm repo update > /dev/null
    local helmResponse=$(helm search repo $1 --version $2 --output json)
    [[ $helmResponse != "[]" ]]
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
    requireArg "a chart path" "$2" || return 1

    local source="$1"
    local chartPath="$2"

    local chartVersion;
    if [[ $source = "remote" ]]; then
        chartVersion=$(helmChartGetLatestRemoteVersion "$chartPath")
    elif [[ $source = "local" ]]; then
        chartVersion=$(helmChartGetLocalVersion "$chartPath")
    else return 1; fi
    [[ $? -ne 0 ]] && return 1

    echo $chartVersion
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
