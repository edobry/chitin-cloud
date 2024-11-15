function gcloudGkeGetClusters() {
    gcloud container clusters list --format=json | jq -c
}

function gcloudGkeListClusters() {
    gcloudGkeGetClusters | jq -r '.[].name'
}

function gcloudGkeGetCluster() {
    requireArg "a cluster name" "$1" || return 1

    gcloud container clusters list --filter="$1" --format=json | jq -c
}

function gcloudGkeGetClusterRegion() {
    requireArg "a cluster name" "$1" || return 1

    gcloudGkeGetCluster "$1" | jq -r '.[0].location'
}

function gcloudGkeClusterInit() {
    requireArg "a region" "$1" || return 1
    requireArg "a cluster name" "$2" || return 1

    local project="${3:"$(gcloudGetProject)"}"

    gcloud container clusters get-credentials "$2" --region "$1" --project "$project"
}

function gcloudGkeClusterInitFromEntry() {
    requireArg "a cluster config entry" "$1" || return 1

    local cluster="$1"

    local region="$(jsonReadPath "$cluster" value region)"
    local name="$(jsonReadPath "$cluster" value name)"
    local project="$(jsonReadPath "$cluster" value project)"

    gcloudGkeClusterInit "$region" "$name" "$project"
}

function gcloudGkeRegisterClusters() {
    gcloudCheckAuthAndFail || return 1

    local iter

    while IFS= read -r cluster; do
        local clusterName=$(jsonReadPath "$cluster" key)

        [[ -z "$iter" ]] || echo ""
        echo "Registering GKE cluster '$clusterName'..."
        iter=' '

        gcloudGkeClusterInitFromEntry "$cluster"
    done <<< "${1:"$(gcloudGkeGetKnownClusters)"}"
}

function gcloudGkeRegisterKnownCluster() {
    requireArg "a cluster name" "$1" || return 1

    local cluster="$(echo "${2:"$(gcloudGkeGetKnownClusters)"}" | jq -sr --arg name "$1" '.[] | select(.key == $name)')"

    gcloudGkeClusterInitFromEntry "$cluster"
}

function gcloudGkeGetKnownClusters() {
    chiConfigChainReadField cloud:gcloud gkeClusters | jq -c 'to_entries[]'
}
