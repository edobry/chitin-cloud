# gets the token for a given ServiceAccount
# args: svc acc name
function k8sGetServiceAccountToken() {
    requireArg "a service account name" "$1" || return 1
    chiCloudPlatformCheckAuthAndFail || return 1

    local serviceAccountTokenName=$(kubectl get serviceaccounts $1 -o json | jq -r '.secrets[0].name')
    kubectl get secrets $serviceAccountTokenName -o json | jq -r '.data.token' | base64Decode
}

# creates a temporary k8s context for a ServiceAccount
# args: svc acc name
function k8sCreateTmpSvcAccContext() {
    requireArg "a service account name" "$1" || return 1
    local svcAccountName="$1"

    local token="$(k8sGetServiceAccountToken "$svcAccountName")"
    kubectl config set-credentials "$svcAccountName" --token "$token" > /dev/null

    local currentCtx="$(k8sGetCurrentContext)"

    local ctxName="tmp-ctx-svc-acc-$svcAccountName"
    kubectl config set-context "$ctxName" \
        --cluster "$(jsonReadPath "$currentCtx" cluster)" \
        --namespace "$(jsonReadPath "$currentCtx" namespace)" \
        --user "$svcAccountName" > /dev/null

    echo "$ctxName"
}

# impersonates a given ServiceAccount and runs a command
# args: svc acc name, command name, command args (optional[])
function k8sRunAsServiceAccount() {
    requireArg "a service account name" "$1" || return 1
    requireArg "a command name" "$2" || return 1
    chiCloudPlatformCheckAuthAndFail || return 1

    local svcAccountName="$1"
    local command="$2"
    shift; shift

    echo "Creating temporary service account context for '$svcAccountName'..."
    local ctxName="$(k8sCreateTmpSvcAccContext $svcAccountName)"
    local currentCtx="$(kubectx -c)"
    kubectx "$ctxName"

    echo "Running command in context..."
    echo -e "\n------ START COMMAND OUTPUT ------"
    $command $*
    echo -e "------ END COMMAND OUTPUT ------\n"

    echo "Cleaning up temporary context..."
    kubectx "$currentCtx"
    k8sDeleteContext "$ctxName"
}

# impersonates a given ServiceAccount and runs a kubectl command using its token
# args: svc acc name, kubectl command name, command args (optional[])
function kubectlAsServiceAccount() {
    requireArg "a service account name" "$1" || return 1
    requireArg "a kubectl command to run" "$2" || return 1

    local svcAccountName="$1"
    shift

    k8sRunAsServiceAccount "$svcAccountName" kubectl $*
}
