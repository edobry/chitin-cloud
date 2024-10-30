function gcloudGkeGetClusters() {
    gcloud container clusters list --format=json | jq -c
}

function gcloudGkeListClusters() {
    gcloudGkeGetClusters | jq -r '.[].name'
}

function gcloudGkeClusterInit() {
    requireArg "a project name" "$1" || return 1
    requireArg "a region" "$2" || return 1
    requireArg "a cluster name" "$3" || return 1

    gcloud container clusters get-credentials "$3" --region "$2" --project "$1"
}
