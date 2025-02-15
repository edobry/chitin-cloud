function k8sCreateMergedConfig() {
    # requireArg "a context name" "$1" || return 1
    
    cp $HOME/.kube/config $HOME/.kube/config.bak
    kubectl config view --minify=true > $HOME/.kube/config
}

function minikubeStart() {
    requireArg "a cluster alias" "$1" || return 1
    requireArg "a project" "$2" || return 1
    requireArg "a region" "$3" || return 1
    requireArg "a cluster name" "$4" || return 1

    local alias="$1"
    local project="$2"
    local region="$3"
    local name="$4"

    local kubeConfig="${5:-$KUBECONFIG}"

    if k8sCheckContextExists "$alias"; then
        chiLog "context '$alias' already exists, skipping..." "cloud:gcloud"
        return 0
    fi

    KUBECONFIG="$CHI_CLOUD_K8S_KUBECONFIG" gcloud container clusters get-credentials "$name" \
        --region "$region" --project "$project"

    local generatedName="gke_${project}_${region}_${name}"
    kubectl --kubeconfig "$kubeConfig" config rename-context "$generatedName" "$alias"
}
