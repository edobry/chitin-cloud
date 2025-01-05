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
    requireArg "a cluster alias" "$1" || return 1
    requireArg "a project" "$2" || return 1
    requireArg "a region" "$3" || return 1
    requireArg "a cluster name" "$4" || return 1

    local alias="$1"
    local project="$2"
    local region="$3"
    local name="$4"

    local kubeConfig="${5:-$KUBECONFIG}"

    if k8sCheckContextExists "$alias"; then
        chiLogInfo "context '$alias' already exists, skipping..." cloud gcloud
        return 0
    fi

    KUBECONFIG="$kubeConfig" gcloud container clusters get-credentials "$name" \
        --region "$region" --project "$project"

    local generatedName="gke_${project}_${region}_${name}"
    kubectl --kubeconfig "$kubeConfig" config rename-context "$generatedName" "$alias"
}

function gcloudGkeClusterInitFromEntry() {
    requireArg "a cluster config entry" "$1" || return 1

    local cluster="$1"

    local alias="$(jsonReadPath "$cluster" key)"
    local project="$(jsonReadPath "$cluster" value project)"
    local region="$(jsonReadPath "$cluster" value region)"
    local name="$(jsonReadPath "$cluster" value name)"

    gcloudGkeClusterInit "$alias" "$project" "$region" "$name" "$2"
}

function gcloudGkeRegisterClusters() {
    gcloudCheckAuthAndFail || return 1

    local defaultRegion
    if [[ "$1" == "defaultRegion" ]]; then
        defaultRegion="$2"; shift; shift
    fi

    local iter

    while IFS= read -r cluster; do
        local alias=$(jsonReadPath "$cluster" key)

        [[ -z "$iter" ]] || echo ""
        chiLogInfo "registering GKE cluster '$alias'..." cloud gcloud
        iter=' '

        gcloudGkeClusterInitFromEntry "$cluster" "$CHI_CLOUD_K8S_KUBECONFIG"
    done <<< "${1:"$(gcloudGkeGetKnownClusters)"}"
}

function gcloudGkeRegisterKnownCluster() {
    requireArg "a cluster name" "$1" || return 1

    local cluster="$(echo "${2:"$(gcloudGkeGetKnownClusters)"}" | jq -sr --arg name "$1" '.[] | select(.key == $name)')"

    gcloudGkeClusterInitFromEntry "$cluster"
}

function gcloudGkeGetKnownClusters() {
    chiConfigUserRead cloud gcloud gkeClusters | jq -c 'to_entries[]'
}
