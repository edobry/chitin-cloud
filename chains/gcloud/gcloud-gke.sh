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

    local currentProject=$(gcloudGetProject)

    gcloud container clusters get-credentials "$2" --region "$1" --project "$currentProject"
}
