function gcloudKmsListLocations() {
    gcloud kms locations list $*
}

function gcloudKmsGetLocations() {
    gcloudKmsListLocations --format=json | jq -c
}

function gcloudKmsListLocationUris() {
    gcloudKmsListLocations --uri
}

function gcloudKmsListLocationIds() {
    gcloudKmsGetLocations | jq -r '.[].locationId'
}

function gcloudKmsListKeyrings() {
    requireArg "a location" "$1" || return 1

    local location="$1"; shift

    gcloud kms keyrings list --location "$location" $*
}

function gcloudKmsListKeys() {
    requireArg "a location" "$1" || return 1
    requireArg "a keyring" "$2" || return 1

    local location="$1"; shift
    local keyring="$1"; shift

    gcloud kms keys list --location "$location" --keyring "$keyring" $*
}

function gcloudKmsGetKeys() {
    requireArg "a location" "$1" || return 1
    requireArg "a keyring" "$2" || return 1

    local location="$1"; shift
    local keyring="$1"; shift

    gcloudKmsListKeys "$location" "$keyring" --format=json | jq -c
}

function gcloudKmsListKeyNames() {
    requireArg "a location" "$1" || return 1
    requireArg "a keyring" "$2" || return 1

    local location="$1"; shift
    local keyring="$1"; shift

    gcloudKmsGetKeys "$location" "$keyring" | jq -r '.[].name'
}
