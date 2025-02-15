# scales a Deployment to the provided replica count
# args: Deployment name, replica count
function k8sScaleDeployment() {
    requireArg "a deployment name" "$1" || return 1
    requireNumericArg "a replica count" "$2" || return 1
    
    kubectl scale deployment "$1" --replicas="$2"
}

# scales a StatefulSet to the provided replica count
# args: StatefulSet name, replica count
function k8sScaleStatefulSet() {
    requireArg "a StatefulSet name" "$1" || return 1
    requireNumericArg "a replica count" "$2" || return 1
    
    kubectl scale statefulset "$1" --replicas="$2"
}

# scales down a deployment to 0 replicas, effectively pausing
# args: deployment name
function k8sScaleDeploymentToZero() {
    requireArg "a deployment name" "$1" || return 1
    
    k8sScaleDeployment "$1" 0
}

# scales down a deployment to 0 replicas, and awaits the operation's completion
# args: deployment name
function k8sScaleDeploymentToZeroAndWait() {
    requireArg "a deployment name" "$1" || return 1

    k8sScaleDeploymentToZero "$1"
    k8sWaitForDeploymentScaleDown "$1"
}

# scales a previously-paused deployment back up to 1 replica
# args: deployment name
function k8sScaleDeploymentToOne() {
    requireArg "a deployment name" "$1" || return 1

    k8sScaleDeployment "$1" 1
}

# cycles a deployment, useful when you want to trigger a restart
# args: deployment name
function k8sReDeploy() {
    requireArg "a deployment name" "$1" || return 1

    k8sScaleDeploymentToZero "$1"
    k8sScaleDeploymentToOne "$1"
}

# checks whether a given Deployment has running pods under management
# args: deployment name
function k8sCheckDeploymentHasPods() {
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

    while k8sCheckDeploymentHasPods "$1"
    do
        echo "Waiting for scale down..."
    done

    echo "Deployment '$1' has successfuly scaled down"
}

# kills all pods for a deployment, useful for forcing a restart during dev
# args: deployment name
function k8sKillDeploymentPods() {
    requireArg "a deployment name" "$1" || return 1

    k8sDeletePodsWithSelector "$(k8sSelectorMakeInstanceLabel "$1")"
}

function k8sSnapshotAndScale() {
    requireArg "a namespace" "$1" || return 1
    requireArg "a persistent volume claim name" "$2" || return 1
    requireArg "a deployment" "$3" || return 1
    requireArg "a template file" "$4" || return 1

    local namespace="$1"
    local pvcName="$2"
    local deployment="$3"
    local templateFile="$4"

    local volumeId=$(k8sFindVolumeIdByPvc "$namespace" "$pvcName")
    [[ -z "$volumeId" ]] && return

    local replicas="$(kubectl get deployment "$deployment" -o jsonpath='{.spec.replicas}')"

    if [[ -z "$replicas" ]]; then
        echo "ERROR: unable to get replicas for deployment: '$deployment' in namespace: '$namespace'"
        return
    fi

    echo "scale deployment '$deployment' to zero"
    k8sScaleDeploymentToZero "$deployment"
    
    echo "take snapshot of $volumeId"
    cat "$templateFile" | sed -e "s/timestamp/$(date '+%Y%m%d%H%M')/g" > ~/snapshot.yaml
    kubectl apply -f ~/snapshot.yaml

    echo "scale deployment $deployment to $replicas replicas"
    k8sScaleDeployment "$deployment" "$replicas"
}

function k8sApplyInstance() {
    requireArg "an instance name" "$1" || return 1
    requireArg "the manifest directory" "$2" || return 1

    kubectl apply -f "$2" -l instance="$1"
}

function k8sDeleteInstance() {
    requireArg "an instance name" "$1" || return 1

    kubectl delete -l instance="$1" $(k8sGetResourceList delete)
}

function k8sDeleteResourcesWithSelector() {
    requireArg "a resource type" "$1" || return 1
    requireArg "a selector" "$2" || return 1

    k8sActionResourceWithSelector delete "$1" "$2" -o name
}

function k8sDeletePodsWithSelector() {
    requireArg "a selector" "$1" || return 1

    k8sDeleteResourcesWithSelector pods "$1"
}

function k8sQueryPodEnvvars() {
    requireArg "a pod name" "$1" || return 1

    kubectl exec -it "$1" -- env
}
