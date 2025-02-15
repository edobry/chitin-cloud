function gcloudComputeGetRegions() {
    gcloud compute regions list --format=json | jq -c '.[] | { id, name, status, zones }'
}

function gcloudComputeListRegions() {
    gcloudComputeGetRegions | jq -r '.name'
}

function gcloudListSnapshots() {
    gcloud compute snapshots list --format="get(name)"
}

function gcloudGetSnapshots() {
    gcloud compute snapshots list --format=json 2>/dev/null | jq -c
}

function gcloudGetSnapshot() {
    requireArg "a snapshot name" "$1" || return 1

    gcloud compute snapshots list --filter="name=($1)" --format=json | jq -c
}

function gcloudCreateSnapshot() {
    requireArg "a disk name" "$1" || return 1
    requireArg "a snapshot name" "$2" || return 1

    gcloud compute snapshots create "$2" --source-disk="$2"
}
