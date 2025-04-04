function chiK8sAddToKubeconfig() {
    requireArg "a KUBECONFIG file" "$1" || return 1

    chiAddToPathVar KUBECONFIG "$1"
}

function chiK8sRemoveFromKubeconfig() {
    requireArg "a KUBECONFIG file" "$1" || return 1

    chiRemoveFromPathVar KUBECONFIG "$1"
}

export CHI_CLOUD_K8S_KUBECONFIG="$CHI_SHARE/kubeconfig.yaml"

function chiK8sConfigureKubeconfig() {
    chiK8sAddToKubeconfig "$CHI_CLOUD_K8S_KUBECONFIG"
}
chiK8sConfigureKubeconfig

function k8sInitConfig() {
    if [[ ! -f "$CHI_CLOUD_K8S_KUBECONFIG" ]]; then
        chiLogInfo "Initializing k8s-env configuration..." cloud k8s
        # gcloudAuth && gcloudGkeRegisterClusters
    fi
}
# k8sInitConfig

function k8sGetContext() {
    requireArg "a context name" "$1" || return 1

    kubectl config view -o json | jq -cr --arg ctx "$1" \
        '.contexts[] | select(.name == $ctx).context | .alias = $ctx'
}

function k8sGetContextCluster() {
    requireArg "a context name" "$1" || return 1

    k8sGetContext "$1" | jq -r '.cluster'
}

# gets the current k8s context config
function k8sGetCurrentContext() {
    k8sGetContext "$(kubectl config current-context)"
}

# deletes a k8s context
# args: context name
function k8sDeleteContext() {
    requireArg "a context name" "$1" || return 1
    local contextName="$1"

    kubectl config delete-context $contextName
}

function k9sEnv() {
    requireArg "a K8s context name" "$1" || return 1
    requireArg "a K8s namespace name" "$2" || return 1

    echo "Launching K9s in context '$1', namespace '$2'"
    k9s --context "$1" --namespace "$2" -c deployments
}

function k8sListContexts() {
    kubectl config get-contexts --output name
}

function k8sCheckContextExists() {
    requireArg "a context name" "$1" || return 1

    k8sListContexts | ggrep -q "^$1$"
}

function k8sListNamespaces() {
    chiCloudPlatformCheckAuthAndFail || return 1

    local contextVar=${1:+"--context="}${1}
    kubectl ${contextVar} get namespaces --output name | sed 's/namespace\///'
}
