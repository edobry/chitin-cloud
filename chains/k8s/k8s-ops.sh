# scales down a deployment to 0 replicas, effectively pausing
# args: deployment name
function k8sDownDeploy() {
    requireArg "a deployment name" $1 || return 1
    kubectl scale deployment $1 --replicas=0
}

# scales down a deployment to 0 replicas, and awaits the operation's completion
# args: deployment name
function k8sDownDeployAndWait() {
    requireArg "a deployment name" "$1" || return 1

    k8sDownDeploy "$1"
    k8sWaitForDeploymentScaleDown "$1"
}

# scales a previously-paused deployment back up to 1 replica
# args: deployment name
function k8sUpDeploy() {
    requireArg "a deployment name" $1 || return 1
    kubectl scale deployment $1 --replicas=1
}

# cycles a deployment, useful when you want to trigger a restart
# args: deployment name
function k8sReDeploy() {
    requireArg "a deployment name" $1 || return 1

    k8sDownDeploy $1
    k8sUpDeploy $1
}

# checks whether a given Deployment has running pods under management
# args: deployment name
function k8sDeploymentHasPods() {
    requireArg "a deployment name" "$1" || return 1

    k8sGetDeploymentPods "$1" -o=json | jq -e '.items[0]' >/dev/null 2>&1
}

function k8sAwaitPodCondition() {
    requireArg "a pod name" "$1" || return 1
    requireArg "a condition" "$2" || return 1

    kubectl wait --for=condition="$2" "pod/$1"
}

# waits until all pods under management of a given Deployment have scaled down
# args: deployment name
function k8sWaitForDeploymentScaleDown() {
    requireArg "a deployment name" "$1" || return 1

    local deploymentName="$1"

    while k8sDeploymentHasPods "$deploymentName"
    do
        echo "Waiting for scale down..."
    done

    echo "Deployment '$1' has successfuly scaled down"
}

# kills all pods for a deployment, useful for forcing a restart during dev
# args: deployment name
function k8sKillDeploymentPods() {
    requireArg "a deployment name" $1 || return 1
    local deployment="$1"

    kubectl delete pods --selector app.kubernetes.io/instance=$deployment
}

function k8sSnapshotAndScale() {
    requireArg "a namespace" "$1" || return 1
    requireArg "a persistent volume claim name" "$2" || return 1
    requireArg "a deployment" "$3" || return 1
    requireArg "a template file" "$4" || return 1

    local namespace="$1"
    local persistentVolumeClaimName="$2"
    local deployment="$3"
    local templateFile="$4"

    local volumeId=$(k8sFindVolumeIdByPvc "$1" "$2")

    if [[ -z "$volumeId" ]]; then
        return
    fi

    local replicas="$(kubectl get deployment "$deployment" -o jsonpath='{.spec.replicas}')"

    if [[ -z "$replicas" ]]; then
        echo "ERROR: unable to get replicas for deployment: '$deployment' in namespace: '$namespace'"
        return
    fi

    echo "scale deployment '$deployment' to zero"
    kubectl -n "$namespace" scale deployment "$deployment" --replicas=0
    
    echo "take snapshot of $volumeId"
    cat "$templateFile" | sed -e "s/timestamp/$(date '+%Y%m%d%H%M')/g" > ~/snapshot.yaml
    kubectl -n "$namespace" apply -f ~/snapshot.yaml

    echo "scale deployment $deployment to $replicas replicas"
    kubectl -n "$namespace" scale deployment "$deployment" --replicas=$replicas
}

function k8sDeleteResourcesWithAppLabel() {
    requireArg "a resource type" "$1" || return 1
    requireArg "an app label" "$2" || return 1
    requireArg "an app label value" "$3" || return 1

    k8sActionResourceWithAppLabel delete "$1" "$2" "$3" -o name
}

function k8sDeletePodsWithAppLabel() {
    requireArg "an app label" "$1" || return 1
    requireArg "an app label value" "$2" || return 1

    k8sActionResourceWithAppLabel delete pods "$1" "$2" -o name
}

function k8sQueryPodEnvvars() {
    requireArg "a pod name" "$1" || return 1

    kubectl exec -it "$1" -- env
}
