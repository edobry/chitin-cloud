function gcloudComputeGetRegions() {
    gcloud compute regions list --format=json | jq -c '.[] | { id, name, status, zones }'
}

function gcloudComputeListRegions() {
    gcloudComputeGetRegions | jq -r '.name'
}
