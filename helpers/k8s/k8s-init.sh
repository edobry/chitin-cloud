local moduleConfig
moduleConfig=$(dtModuleShouldLoad k8s return-config k8s-env)
if [[ $? -ne 0 ]]; then
    return 1
fi

CA_DT_K8S_KUBECONFIG="$CA_DT_DIR/shell/eksconfig.yaml"
# set user-readable-only permissions
chmod go-r $CA_DT_K8S_KUBECONFIG 2>/dev/null

local originalConfig="$KUBECONFIG:$HOME/.kube/config"

# TODO: add init var for idempotency
local conditionalPrepend=$(jsonCheckBool 'override' "$moduleConfig" && echo '' || echo "$originalConfig:")
export KUBECONFIG="${conditionalPrepend}${CA_DT_K8S_KUBECONFIG}"

# add krew to PATH
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
