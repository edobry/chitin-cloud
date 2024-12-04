chiRegisterCompletion "$0" || return 0

function _gcloud_complete_projects() {
    _arguments "1: :($(gcloudCheckAuth && gcloudListUniqueProjects))"
}

function _gcloud_complete_regions() {
    _arguments "1: :($(gcloudCheckAuth && gcloudComputeListRegions))"
}

function _gcloud_complete_gke_clusters() {
    _arguments "1: :($(gcloudCheckAuth && gcloudGkeListClusters))"
}

function _gcloud_complete_gke_cluster_init() {
    _arguments \
        "1: :->regions" \
        "2: :->clusters"

    case $state in
        regions)
            compadd $(gcloudComputeListRegions)
            ;;
        clusters)
            compadd $(gcloudGkeListClusters)
            ;;
    esac
}

compdef _gcloud_complete_projects gcloudSetProject gcloudWithProject
compdef _gcloud_complete_gke_clusters gcloudGkeGetCluster gcloudGkeGetClusterRegion
compdef _gcloud_complete_gke_cluster_init gcloudGkeClusterInit
