function k8sInitConfig() {
    if [[ ! -f $CA_DT_K8S_KUBECONFIG ]]; then
        chiLog "Initializing k8s-env configuration..."
        chiModuleLoad $(chiGetLocation)/chains/aws
        awsAuthModuleInit && awsEksRegisterClusters
    fi
}
k8sInitConfig

# gets the current k8s context config
function k8sGetCurrentContext() {
    kubectl config view -o json | jq -cr --arg ctx $(kubectl config current-context) \
        '.contexts[] | select(.name == $ctx).context'
}

# deletes a k8s context
# args: context name
function k8sDeleteContext() {
    requireArg "a context name" "$1" || return 1
    local contextName="$1"

    kubectl config delete-context $contextName
}

function k9sEnv() {
    requireArg "an AWS account name" "$1" || return 1
    requireArg "a K8s context name" "$2" || return 1
    requireArg "a K8s namespace name" "$3" || return 1

    checkAuth "$1" || awsAuth "$1"

    echo "Launching K9s in context '$2', namespace '$3'"
    k9s --context "$2" --namespace "$3" -c deployments
}
