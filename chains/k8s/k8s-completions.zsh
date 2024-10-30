chiRegisterCompletion "$0" || return 0

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

compdef _k8s_complete_pods k8sGetPodConfig

compdef _k8s_complete_services k8sGetServiceExternalUrl k8sGetServiceEndpoint
compdef _k8s_complete_psql_services rds ccCreateTransferDbs

compdef _k8s_complete_deployments k8sDownDeploy k8sDownDeployAndWait k8sUpDeploy k8sReDeploy \
    ccResetBackendDb p2pSnapshotNodeState k8sKillDeploymentPods k8sGetDeploymentSelector \
    k8sGetDeploymentPods k8sDeploymentHasPods k8sWaitForDeploymentScaleDown
