local chainConfig
chainConfig=$(chiChainShouldLoad cloud k8s return-config k8s-env)
if [[ $? -ne 0 ]]; then
    return 1
fi

CHI_K8S_KUBECONFIG="$CA_DT_DIR/eksconfig.yaml"
# set user-readable-only permissions
chmod go-r $CHI_K8S_KUBECONFIG 2>/dev/null

local originalConfig="$KUBECONFIG:$HOME/.kube/config"

# TODO: add init var for idempotency
local conditionalPrepend=$(jsonCheckBool 'override' "$chainConfig" && echo '' || echo "$originalConfig:")
export KUBECONFIG="${conditionalPrepend}${CHI_K8S_KUBECONFIG}"

# add krew to PATH
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
