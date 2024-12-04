function gcloudConfigPath() {
    gcloud info --format="get(config.paths.active_config_path)"
}

function gcloudDockerConfigure() {
    requireArg "a registry name" "$1" || return 1

    gcloud auth configure-docker
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

function gcloudShowWorkflows() {
    gcloud workflows list $*
}

function gcloudGetWorkflows() {
    gcloudShowWorkflows --format=json | jq
}

function gcloudListWorkflows() {
    gcloudShowWorkflows --format="get(name)" | cut -d '/' -f6
}

function gcloudListWorkflows() {
    gcloudShowWorkflows --format="get(name)" | cut -d '/' -f6
}

function gcloudGetWorkflow() {
    requireArg "a workflow name" "$1" || return 1

    gcloud workflows describe "$1" --format=json 2>/dev/null | jq -c
}

function gcloudListWorkflowSteps() {
    requireArg "a workflow name" "$1" || return 1

    gcloudGetWorkflow "$1" | jq -r '.sourceContents' \
        | sed -E 's/(^|[^"])((\$\{[^}]+\}))($|[^"])/\1'''\2'''\4/g' | yq -o=json \
        | jq -r '[.[] | to_entries] | add[] | "\(.key)"'
}

function gcloudRunWorkflow() {
    requireArg "a workflow name" "$1" || return 1

    local workflowName="$1"; shift

    gcloud workflows run "$workflowName" --call-log-level=log-all-calls $*
}
