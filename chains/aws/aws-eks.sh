function awsEksExtractImageVersion() {
    requireArg "an EKS Docker image" "$1" || return 1

    echo "$1" | cut -d ":" -f 2 | sed 's/-eksbuild\.1//'
}

function awsEksGetImageVersion() {
    requireArg "a resource type" "$1" || return 1
    requireArg "a resource identifier" "$2" || return 1
    requireArg "a namespace" "$3" || return 1

    local resourceType="$1"
    local resourceId="$2"
    local namespace="$3"

    echo "Checking current version of $resourceId..."
    local currentImage=$(k8sGetImage $resourceType $resourceId $namespace)

    awsEksExtractImageVersion "$currentImage"
}

function awsEksUpgradeComponent() {
    requireArg "a resource type" "$1" || return 1
    requireArg "a resource identifier" "$2" || return 1
    requireArg "a namespace" "$3" || return 1
    requireArg "the new version" "$4" || return 1
    checkAuthAndFail || return 1

    local resourceType="$1"
    local resourceId="$2"
    local namespace="$3"
    local newVersion="v$4"

    local currentImage=$(k8sGetImage $resourceType $resourceId $namespace)
    local currentVersion=$(awsEksExtractImageVersion $currentImage)

    if [[ $currentVersion == $newVersion ]]; then
        echo "Current version of $resourceId is already up-to-date!"
        return 0
    fi

    local newVersionImage=$(echo "$currentImage" | awk -F':' -v ver="$newVersion" '{ print $1 ":" ver "-eksbuild.1" }')

    echo "Upgrading version of $resourceId from $currentVersion to $newVersion..."
    kubectl set image $resourceType.apps/$resourceId \
        -n $namespace $resourceId=$newVersionImage

    echo "Done!"
}

# pulls relevant cni upgrade script from public aws repo and applies
# will run against the current kubectx
function awsEksUpgradeVpcCniPlugin() {

    requireArg "the new version" "$1" || return 1 # format 1.10 or 1.11 will update to the latest of this version
    checkAuthAndFail || return 1

    local newVersion="$1"

    kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-$newVersion/config/master/aws-k8s-cni.yaml

    echo "Done now at version $newVersion"
    echo "To check \n"
    echo "kubectl describe daemonset aws-node --namespace kube-system | grep Image | cut -d "/" -f 2"
}

function awsEksUpgrade() {
    requireArg "the new K8s version" "$1" || return 1
    requireArg "the new kube-proxy version" "$2" || return 1
    requireArg "the new CoreDNS version" "$3" || return 1
    requireArg "the new VPC CNI Plugin version" "$3" || return 1
    requireArg "the region" "$4" || return 1
    checkAuthAndFail || return 1

    local newClusterVersion="$1"
    local newKubeProxyVersion="$2"
    local newCoreDnsVersion="$3"
    local newVpcCniPluginVersion="$4"
    local region="$4"

    echo "Upgrading cluster components to version $newClusterVersion..."

    awsEksUpgradeComponent daemonset kube-proxy kube-system $newKubeProxyVersion
    awsEksUpgradeComponent deployment coredns kube-system $newCoreDnsVersion
    awsEksUpgradeVpcCniPlugin $newVpcCniPluginVersion $region
}

function awsEksListNodegroups() {
    requireArg "a cluster name" "$1" || return 1
    checkAuthAndFail || return 1

    aws eks list-nodegroups --cluster-name "$1" | jq -r '.nodegroups[]'
}

function awsEksListClusters() {
    checkAuthAndFail || return 1

    aws eks list-clusters | jq -r '.clusters[]'
}

function awsEksRegisterCluster() {
    requireArg "a cluster name" "$1" || return 1
    requireArg "a cluster alias" "$2" || return 1
    checkAuthAndFail || return 1

    local dryRun=$([[ "$3" == 'dryrun' ]] && echo '--dry-run' || echo '')

    aws eks update-kubeconfig --name "$1" --alias "$2" --kubeconfig $CHI_CLOUD_K8S_KUBECONFIG $dryRun
}

function awsEksRegisterClusters() {
    checkAuthAndFail || return 1

    local iter

    while IFS= read -r cluster; do
        local clusterName=$(jsonRead "$cluster" '.key')

        [[ -z "$iter" ]] || echo ""
        echo "Registering cluster $clusterName..."
        iter=' '

        local profileArgs=$(echo "$cluster" | jq -r '"\(.value.role) awsEksRegisterCluster \(.value.name) \(.key)"')
        withProfile $profileArgs
    done <<< $(awsEksGetKnownClusters)
}

function awsEksRegisterKnownCluster() {
    requireArg "a context name" "$1" || return 1

    local cluster=$(awsEksGetKnownClusters | jq -sr --arg ctx "$1" '.[] | select(.key == $ctx).value.name')

    awsEksRegisterCluster $cluster "$1"
}

function awsEksGetKnownClusters() {
    local inlineClusters=$(chiConfigChainReadField 'cloud:aws' 'eksClusters' | jq -c 'to_entries[]')

    local eksFilePath
    eksFilePath=$(json5Convert $(chiGetLocation)/eksClusters.json5)
    [[ $? -eq 0 ]] || return 1
    local defaultClusters=$(jsonReadFile "$eksFilePath" | jq -c 'to_entries[]')

    echo -e "$defaultClusters\n$inlineClusters"
}

function awsEksUpdateNodegroups() {
    requireArg "a cluster name" "$1" || return 1
    checkAuthAndFail || return 1

    local clusterName="$1"
    local nodeGroups=$(awsEksListNodegroups $clusterName)

    echo "Updating node groups for cluster $clusterName..."

    echo $nodeGroups |\
    while read -r nodegroup; do
        echo -e "Starting update for node group $nodegroup..."
        awsEksUpdateNodegroup $clusterName $nodegroup
    done

    echo -e "\nWaiting for node group updates to complete..."

    echo $nodeGroups |\
    while read -r nodegroup; do
        echo "Waiting for $nodegroup..."
        awsEksWaitForNodeGroupActive $clusterName $nodegroup
    done

    echo "Done!"
}

function awsEksUpdateNodegroup() {
    requireArg "a cluster name" "$1" || return 1
    requireArg "a node group name" "$2" || return 1
    checkAuthAndFail || return 1

    local response
    response=$(aws eks update-nodegroup-version --cluster-name $1 --nodegroup-name $2 2>/dev/null)
    [[ $? -eq 0 ]] || return 1

    local updateStatus=$(jsonRead "$response" '.update.status')
    local newVersion=$(jsonRead "$response" '.update.params[] | select(.type == "ReleaseVersion") | .value')

    echo "Status of node group '$2' update to version '$newVersion' is $updateStatus"
}

function awsEksWaitForNodeGroupActive() {
    requireArg "a cluster name" "$1" || return 1
    requireArg "a node group name" "$2" || return 1
    checkAuthAndFail || return 1

    aws eks wait nodegroup-active --cluster-name $1 --nodegroup-name $2
}


function awsEksServiceGetExternalDns() {
    requireArg 'an account name' "$1" || return 1
    requireArg 'an EKS cluster name' "$2" || return 1
    requireArg 'an K8s namespace' "$3" || return 1
    requireArg 'a K8s service name' "$4" || return 1

    local zone="$2.$1.e.chainalysis.com"

    local records
    records=$(awsR53GetRecordsJson "$zone")
    if [[ $? -ne 0 ]]; then
        echo "$records"
        return 1
    fi

    local names=$(awsR53QueryTxtRecords "$zone" \
        "contains(\"external-dns/owner=$2\") and
         contains(\"external-dns/resource=service/$3/$4\")" \
         "$records")

    local joinedNames=$(echo "$names" | jq -r '.[] | .Name' | replaceNewlines)

    echo "$records" | jq -r --arg names "$joinedNames" '.[] | select(.Type == "A" and (.Name | IN(($names | split(" "))[]))) | .Name'
}

function awsEksGetContextClusterName() {
    requireArg 'a cluster name' "$1" || return 1

    kubectl config view -o=json | jq -r --arg name "$1" '.contexts[] | select(.name == $name) | .context.cluster' | awk -F'/' '{ print $2 }'
}

function awsEksGetCurrentContextClusterName() {
    awsEksGetContextClusterName $(kubectl config current-context)
}
