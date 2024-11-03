# prints your current account if authenticated, or fails
function gcloudId() {
    local id=$(gcloud auth list --format=json | jq -c) 2> /dev/null
    if echo "$id" | jq -e 'length != 0' > /dev/null; then
        echo $id
    else
        return 1
    fi
}

function gcloudAccount() {
    gcloudCheckAuthAndFail || return 1
    
    gcloudId | jq -r '.[] | select(.status == "ACTIVE") | .account'
}

# checks if you're authenticated, or fails. meant to be used as a failfast
function gcloudCheckAuthAndFail() {
    if ! gcloudCheckAuth; then
        echo "Please authenticate with Google Cloud before rerunning."
        return 1
    fi
}

# checks if you're authenticated
function gcloudCheckAuth() {
    if ! gcloudId > /dev/null 2>&1; then
        echo "Unauthenticated!"
        return 1
    fi
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
