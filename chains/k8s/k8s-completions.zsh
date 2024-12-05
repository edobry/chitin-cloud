chiRegisterCompletion "$0" || return 0

function _k8s_complete_contexts() {
    _arguments "1: :($(k8sListContexts))"
}

function _k8s_complete_namespaces() {
    _arguments "1: :($(k8sListNamespaces))"
}

function _k8s_complete_ctx_and_ns() {
    local state
    _arguments "1:context:($(k8sListContexts))" \
               "2:namespace:->namespace"

    case $state in
        (namespace)
            compadd $(k8sListNamespaces $words[2])
            ;;
    esac
}

function _k8s_complete_pods() {
    _arguments "1: :($(k8sListPods))"
}

function _k8s_complete_deployments() {
    _arguments "1: :($(k8sListDeployments))"
}

function _k8s_complete_services() {
    _arguments "1: :($(k8sListServices))"
}

function _k8s_complete_psql_services() {
    _arguments "1: :($(k8sListPostgresServices))"
}

compdef _k8s_complete_contexts k8sListNamespaces
compdef _k8s_complete_pods k8sGetPodConfig k8sQueryPodEnvvars

compdef _k8s_complete_services k8sGetServiceExternalUrl k8sGetServiceEndpoint
compdef _k8s_complete_contexts k8sListExternalDnsEndpoints

compdef _k8s_complete_deployments k8sDownDeploy k8sDownDeployAndWait k8sUpDeploy k8sReDeploy \
    k8sKillDeploymentPods k8sGetDeploymentSelector k8sGetDeploymentPods k8sDeploymentHasPods k8sWaitForDeploymentScaleDown
