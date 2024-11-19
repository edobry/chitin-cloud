function gcloudConfigPath() {
    gcloud info --format="get(config.paths.active_config_path)"
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
