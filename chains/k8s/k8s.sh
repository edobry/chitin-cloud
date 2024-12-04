# base64-encodes a string for use in a Secret
function k8sSecretEncode() {
    requireArg "a secret" $1 || return 1

    echo -n "$1" | base64 | toClip
}

# deprecated older version of the debug pod, only creates, does not manage lifecyle
function k8sNetshoot() {
    kubectl run --generator=run-pod/v1 tmp-shell --rm -i --tty --image nicolaka/netshoot -- /bin/bash
}

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

CHI_CLOUD_K8S_DASHBOARD_NAMESPACE="kubernetes-dashboard"

# fetches the admin user token, can be used for authorizing with the dashboard
function k8sGetAdminToken() {
    local user="admin-user"

    local adminSecret="$(kubectl -n "$CHI_CLOUD_K8S_DASHBOARD_NAMESPACE" get secret | grep "$user" | awk '{print $1}')"
    kubectl -n "$CHI_CLOUD_K8S_DASHBOARD_NAMESPACE" describe secret "$adminSecret" | grep 'token:' | awk '{print $2}' | toClip
}

function k8sDashboard() {
    echo "Launching dashboard..."
    echo "Copying token to clipboard..."
    k8sGetAdminToken

    echo -e "\nOpening URL (might need a refresh):"
    local url="http://localhost:8001/api/v1/namespaces/$CHI_CLOUD_K8S_DASHBOARD_NAMESPACE/services/https:dashboard-kubernetes-dashboard:https/proxy/"
    echo -e "\n$url\n"

    openUrl "$url"

    kubectl proxy
}

function k8sGetPodConfig() {
    requireArg "a pod name" $1 || return 1
    kubectl get pod -o yaml $1 | bat -p -l yaml
}

# fetches the external url, with port, for a Service with a load balancer configured
# args: service name
function k8sGetServiceExternalUrl() {
    requireArg "a service name" $1 || return 1

    local svc=$(kubectl get service $1 -o=json)
    local hostname=$(echo "$svc" | jq -r '.status.loadBalancer.ingress[0].hostname')
    local port=$(echo "$svc" | jq -r '.spec.ports[0].port')

    echo "$hostname:$port"
}

# fetch the endpoint url for both services and proxies to zen garden
function k8sGetServiceEndpoint() {
    requireArg "a service name" $1 || return 1

    service=$(kubectl describe services $1)
    kind=$(grep "Type:" <<< $service | awk '{print $2}')
    if [[ $kind == 'ClusterIP' ]]; then
        echo $(grep 'Endpoints' <<< $service | awk '{print $2}')
        return
    fi
    if [ $kind = 'ExternalName' ]; then
        echo $(grep 'External Name' <<< $service | awk '{print $3}')
        return
    fi
    echo "Unknown service type"
}

# kills all pods for a deployment, useful for forcing a restart during dev
# args: deployment name
function k8sKillDeploymentPods() {
    requireArg "a deployment name" $1 || return 1
    local deployment="$1"

    kubectl delete pods --selector app.kubernetes.io/instance=$deployment
}

# gets the container image for a given resource
# args: resource type, resource id, namespace
function k8sGetImage() {
    requireArg "a resource type" "$1" || return 1
    requireArg "a resource identifier" "$2" || return 1
    requireArg "a namespace" "$3" || return 1

    local resourceType="$1"
    local resourceId="$2"
    local namespace="$3"

    kubectl get $resourceType $resourceId --namespace $namespace \
        -o=jsonpath='{$.spec.template.spec.containers[:1].image}'
}

function k8sFindVolumeIdByPvc() {
    requireArg "a namespace" "$1" || return 1
    requireArg "a persistent volume claim name" "$2" || return 1

    local namespace="$1"
    local persistentVolumeClaimName="$2"

    local volumeName=$(kubectl -n "$namespace" get pvc --field-selector metadata.name="$persistentVolumeClaimName" -o jsonpath='{.items[0].spec.volumeName}')

    if [[ -z "$volumeName" ]]; then
        echo "ERROR: trying to get volumeName for persistentVolumeClaimName "$persistentVolumeClaimName" in namespace $namespace"
        return
    fi

    local volumeId=$(kubectl -n "$namespace" get pv --field-selector metadata.name="$volumeName" -o jsonpath='{.items[0].spec.csi.volumeHandle}')

    if [[ -z "$volumeId" ]]; then
        echo "ERROR: trying to get volumeId/volumeHandle for persistentVolume '$volumeName' in namespace '$namespace'"
        return
    fi

    echo "$volumeId"
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

# gets the token for a given ServiceAccount
# args: svc acc name
function k8sGetServiceAccountToken() {
    requireArg "a service account name" "$1" || return 1
    checkAuthAndFail || return 1

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
    checkAuthAndFail || return 1

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

function k8sNamespaceExists() {
    requireArg "a namespace" "$1" || return 1

    kubectl get namespaces "$1" --output=json > /dev/null 2>&1
}

function k8sCreateNamespace() {
    requireArg "a namespace name" "$1" || return 1

    kubectl create namespace "$1"
}

function k8sAwaitPodCondition() {
    requireArg "a pod name" "$1" || return 1
    requireArg "a condition" "$2" || return 1

    kubectl wait --for=condition="$2" "pod/$1"
}

# gets the pod selector used for a given Deployment
# args: deployment name
function k8sGetDeploymentSelector() {
    requireArg "a deployment name" "$1" || return 1

    kubectl get deployment "$1" --output json | jq -r \
        '.spec.selector.matchLabels | to_entries | map("\(.key)=\(.value)") | join(",")'
}

# gets an annotation value for the given resource
# args: resource type, resource name, annotation
function k8sGetResourceAnnotation() {
    requireArg "a resource type" "$1" || return 1
    requireArg "a resource name" "$2" || return 1
    requireArg "an annotation name" "$3" || return 1

    kubectl get "$1" "$2" --output json | jq -r --arg annotation "$3" \
        '.metadata.annotations[$annotation]'
}

# gets the external hostname created for a given Service
# args: service name
function k8sGetServiceExternalHostname() {
    requireArg "a service name" "$1" || return 1

    k8sGetResourceAnnotation service "$1" 'external-dns.alpha.kubernetes.io/hostname'
}

# gets the pods managed by a given Deployment
# args: deployment name
function k8sGetDeploymentPods() {
    requireArg "a deployment name" "$1" || return 1

    local deploymentName="$1"
    shift

    kubectl get pods --selector="$(k8sGetDeploymentSelector "$deploymentName")" $*
}

# checks whether a given Deployment has running pods under management
# args: deployment name
function k8sDeploymentHasPods() {
    requireArg "a deployment name" "$1" || return 1

    k8sGetDeploymentPods "$1" -o=json | jq -e '.items[0]' >/dev/null 2>&1
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

function k8sListDeployments() {
    kubectl get deployments | tail -n +2 | cut -d ' ' -f 1
}

function k8sListPods() {
    kubectl get pods | tail -n +2 | cut -d ' ' -f 1
}

function k8sListServices() {
    kubectl get services | tail -n +2 | cut -d ' ' -f 1
}

function k8sListPostgresServices() {
    kubectl get services | grep postgres | tail -n +2 | cut -d ' ' -f 1
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

function k8sGetResourceList() {
    requireArg "an API verb" "$1" || return 1

    kubectl api-resources --verbs="$1" -o name | tr '\n' ,| sed 's/,$//'
}

function k8sGetAllResources() {
    kubectl get $(k8sGetResourceList list) --ignore-not-found $@
}

function k8sGetResourcesWithAppLabel() {
    requireArg "a resource type" "$1" || return 1
    requireArg "an app label" "$2" || return 1
    requireArg "an app label value" "$3" || return 1

    k8sActionResourceWithAppLabel get "$1" "$2" "$3" -o custom-columns=:.metadata.name
}

function k8sGetPodsWithAppLabel() {
    requireArg "an app label" "$1" || return 1
    requireArg "an app label value" "$2" || return 1

    k8sGetResourcesWithAppLabel pods "$1" "$2"
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

function k8sActionResourceWithAppLabel() {
    requireArg "an action" "$1" || return 1
    requireArg "a resource type" "$2" || return 1
    requireArg "an app label" "$3" || return 1
    requireArg "an app label value" "$4" || return 1
    checkAuthAndFail || return 1

    local action="$1"
    local resourceType="$2"
    local label="$3"
    local labelValue="$4"
    shift; shift; shift; shift

    kubectl "$action" "$resourceType" --selector="app.kubernetes.io/$label=$labelValue" $@
}
