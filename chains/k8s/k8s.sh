# base64-encodes a string for use in a Secret
function k8sSecretEncode() {
    requireArg "a secret" $1 || return 1

    echo -n "$1" | base64 | toClip
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

function k8sNamespaceExists() {
    requireArg "a namespace" "$1" || return 1

    kubectl get namespaces "$1" --output=json > /dev/null 2>&1
}

function k8sCreateNamespace() {
    requireArg "a namespace name" "$1" || return 1

    kubectl create namespace "$1"
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

    local deploymentName="$1"; shift

    k8sGetPodsWithSelector "$deploymentName" "$(k8sGetDeploymentSelector "$deploymentName")" $*
}

function k8sListResource() {
    requireArg "a resource type" "$1" || return 1

    kubectl get "$1" --output custom-columns=NAME:.metadata.name --no-headers
}

function k8sListDeployments() {
    k8sListResource deployments
}

function k8sListStatefulsets() {
    k8sListResource statefulsets
}

function k8sListPods() {
    k8sListResource pods
}

function k8sListServices() {
    k8sListResource services
}

function k8sGetResourceList() {
    requireArg "an API verb" "$1" || return 1

    kubectl api-resources --verbs="$1" -o name | tr '\n' ,| sed 's/,$//'
}

function k8sGetAllResources() {
    kubectl get $(k8sGetResourceList list) --ignore-not-found $@
}

function k8sSelectorMakeAppLabel() {
    requireArg "an app label" "$1" || return 1
    requireArg "an app label value" "$2" || return 1

    echo "app.kubernetes.io/$1=$2"
}

function k8sSelectorMakeInstanceLabel() {
    requireArg "an instance name" "$1" || return 1

    k8sSelectorMakeAppLabel instance "$1"
}

function k8sGetResourcesWithSelector() {
    requireArg "a resource type" "$1" || return 1
    requireArg "a selector" "$2" || return 1

    k8sActionResourceWithSelector get "$1" "$2" -o custom-columns=:.metadata.name
}

function k8sGetPodsWithSelector() {
    requireArg "a selector" "$1" || return 1

    k8sGetResourcesWithSelector pods "$1"
}

function k8sActionResourceWithSelector() {
    requireArg "an action" "$1" || return 1
    requireArg "a resource type" "$2" || return 1
    requireArg "a selector" "$3" || return 1
    chiCloudPlatformCheckAuthAndFail || return 1

    local action="$1"; shift
    local resourceType="$2"; shift
    local selector="$3"; shift

    kubectl "$action" "$resourceType" --selector="$selector" $@
}

function k8sGetExternalDnsEndpoints() {
    chiCloudPlatformCheckAuthAndFail || return 1

    kubectl get dnsendpoints.externaldns.k8s.io --output=json | jq -c
}

function k8sListExternalDnsEndpoints() {
    chiCloudPlatformCheckAuthAndFail || return 1

    k8sGetExternalDnsEndpoints | jq -r '.items[].spec.endpoints[].dnsName'
}

function k8sListExternalDnsEndpointNames() {
    chiCloudPlatformCheckAuthAndFail || return 1

    k8sGetExternalDnsEndpoints | jq -r '.items[].metadata.name'
}

function k8sGetConfigmap() {
    requireArg "a ConfigMap name" "$1" || return 1

    chiCloudPlatformCheckAuthAndFail || return 1

    kubectl get configmap "$1" --output=json | jq -c
}

function k8sGetConfigmapEntry() {
    requireArg "a ConfigMap name" "$1" || return 1
    requireArg "a ConfigMap entry name" "$2" || return 1

    k8sGetConfigmap "$1" | jq -r --arg name "$2" '.data.[$name]'
}

function k8sPortForward() {
    requireArg "a pod name" "$1" || return 1
    requireArg "a port" "$2" || return 1
    
    kubectl port-forward "$1" "$2:$2"
}
