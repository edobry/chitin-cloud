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
        chiLog "Initializing k8s-env configuration..."
        # gcloudAuth && gcloudGkeRegisterClusters
    fi
}
# k8sInitConfig

# gets the current k8s context config
function k8sGetCurrentContext() {
    kubectl config view -o json | jq -cr --arg ctx $(kubectl config current-context) \
        '.contexts[] | select(.name == $ctx).context | .alias = $ctx'
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
