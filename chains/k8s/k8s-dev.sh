# deprecated older version of the debug pod, only creates, does not manage lifecyle
function k8sNetshoot() {
    kubectl run --generator=run-pod/v1 tmp-shell --rm -i --tty --image nicolaka/netshoot -- /bin/bash
}

CHI_CLOUD_K8S_DASHBOARD_NAMESPACE="kubernetes-dashboard"

# fetches the admin user token, can be used for authorizing with the dashboard
function k8sGetAdminToken() {
    local user="admin-user"

    local adminSecret="$(kubectl -n "$CHI_CLOUD_K8S_DASHBOARD_NAMESPACE" get secret | grep "$user" | awk '{print $1}')"
    kubectl -n "$CHI_CLOUD_K8S_DASHBOARD_NAMESPACE" describe secret "$adminSecret" | grep 'token:' | awk '{print $2}' | toClip
}

function k8sDashboard() {
    echo "Launching dashboard..."
    echo "Copying token to clipboard..."
    k8sGetAdminToken

    echo -e "\nOpening URL (might need a refresh):"
    local url="http://localhost:8001/api/v1/namespaces/$CHI_CLOUD_K8S_DASHBOARD_NAMESPACE/services/https:dashboard-kubernetes-dashboard:https/proxy/"
    echo -e "\n$url\n"

    openUrl "$url"

    kubectl proxy
}
