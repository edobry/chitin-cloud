# prints your current account if authenticated, or fails
function gcloudId() {
    local id=$(gcloud auth list --format=json | jq -c) 2>/dev/null
    if echo "$id" | jq -e 'length != 0' > /dev/null; then
        echo $id
    else
        return 1
    fi
}

function gcloudAccount() {
    chiCloudPlatformCheckAuthAndFail || return 1
    
    gcloudId | jq -r '.[] | select(.status == "ACTIVE") | .account'
}

function gcloudCheckAuth() {
    gcloud auth print-access-token --quiet
}

function gcloudAuth() {
    gcloud auth login --update-adc
}

function gcloudRevoke() {
    gcloud auth revoke --all
}

function gcloudGetProjects() {
    gcloud projects list --format json | jq -c '.[] | { name, id: .projectId }'
}

function gcloudListProjects() {
    gcloudGetProjects | jq -r '.id'
}

function gcloudListUniqueProjects() {
    gcloudListProjects | sort | uniq | replaceNewlines
}

function gcloudGetProject() {
    gcloud config get project --format=json 2> /dev/null | jq -r
}

function gcloudSetProject() {
    requireArg "a project name" "$1" || return 1

    gcloud config set project "$1"
}

function gcloudWithProject() {
    requireArg "a project name" "$1" || return 1

    local projectName="$1"; shift

    gcloud config set project "$projectName"
    $*
}
