function k8sLoadBundledKubeconfig() {
    local chainConfig="$(chiConfigUserRead cloud k8s)"
    local bundledConfig="$(jsonReadPath "$chainConfig" bundledConfig)"
    [[ -z "$bundledConfig" ]] && return 0

    local bundledConfigPath="$(chiExpandPath $(jsonReadPath "$bundledConfig" path))"
    if [[ -z "$bundledConfigPath" ]]; then
        chiLogError "bundled kubeconfig path not set!" cloud k8s
        return 1
    fi

    if [[ ! -f "$bundledConfigPath" ]]; then
        chiLogError "configured bundled kubeconfig not found at '$bundledConfigPath'!" cloud k8s
        return 1
    fi

    export CHI_CLOUD_K8S_KUBECONFIG="$bundledConfigPath"
    
    # set user-readable-only permissions
    chmod go-r "$CHI_CLOUD_K8S_KUBECONFIG" 2>/dev/null

    local originalConfig="$KUBECONFIG:$HOME/.kube/config"

    # TODO: add init var for idempotency
    local conditionalPrepend="$originalConfig:"
    jsonCheckBool "$bundledConfig" override && conditionalPrepend=''
    
    export KUBECONFIG="${conditionalPrepend}${CHI_CLOUD_K8S_KUBECONFIG}"
}

# k8sLoadBundledKubeconfig

# add krew to PATH
KREW_PATH="${KREW_ROOT:-$HOME/.krew}"
if [[ -d "$KREW_PATH" ]]; then
    chiToolsAddDirToPath "$KREW_PATH/bin"
fi
