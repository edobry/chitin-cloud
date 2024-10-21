checkCommand compdef || return 0

function _aws_complete_availability_zones() {
    _arguments "1: :($(checkAuth && awsListAZsInCurrentRegion))"
}

function _aws_complete_volumes() {
    _arguments "1: :($(checkAuth && awsEbsListVolumes))"
}

function _aws_complete_snapshots() {
    _arguments "1: :($(checkAuth && awsEbsListSnapshots))"
}

function _aws_complete_databases() {
    _arguments "1: :($(checkAuth && awsRdsListDatabases))"
}

function _aws_complete_zones() {
    _arguments "1: :($(checkAuth && awsR53ListZones))"
}

function _aws_complete_kafka_clusters() {
    _arguments "1: :($(checkAuth && awsMskListClusterNames))"
}

function _aws_complete_eks_clusters() {
    _arguments "1: :($(checkAuth && awsEksListClusters))"
}

function _aws_complete_ssm_params() {
    _arguments "1: :($(checkAuth && awsSsmListParams))"
}

function _aws_complete_roles() {
    _arguments "1: :($(awsIamListRoles))"
}

function _aws_complete_users() {
    _arguments "1: :($(awsIamListUsers))"
}

function _aws_complete_eks_nodegroups() {
    local state
    _arguments "1: :($(checkAuth && awsEksListClusters))" \
               "2:terraform env:->nodegroups"

    case $state in
        (nodegroups)
            compadd $(awsEksListNodegroups $words[2])
            ;;
    esac
}

function _aws_complete_asg() {
    _arguments "1:Autoscaling Groups:($(awsAsgList))"
}

function _aws_complete_ec2_instances() {
    _arguments "1:EC2 instances:($(awsEc2ListInstances))"
}

function _aws_complete_ec2_keypairs() {
    _arguments "1:EC2 keypair:($(awsEc2ListKeypairs))"
}

compdef _aws_complete_roles awsIamCreateProgrammaticCreds awsIamGetAssumeRolePolicyDocument awsIamDeleteRole awsIamGetRoleArn awsIamAssumeRole awsIamAssumeRoleShell
compdef _aws_complete_users awsIamListUserPolicies
compdef _aws_complete_ec2_keypairs awsEc2DeleteKeypair awsEc2DownloadKeypair
compdef _aws_complete_ec2_instances awsEc2FindInstancesByName awsEc2GetInstanceKeypairName

compdef _aws_complete_ssm_params awsSsmGetParam awsSsmSetParam

compdef _aws_complete_availability_zones createVolume
compdef _aws_complete_volumes awsEbsWatchVolumeModificationProgress awsEbsSnapshotVolume \
    awsEbsDeleteVolume awsEbsResizeVolume awsEbsShowVolumeTags awsEbsTagVolume
compdef _aws_complete_snapshots awsEbsWatchSnapshotProgress

compdef _aws_complete_databases awsawsRdsSnapshot awsRdsGetInstanceEndpoint

compdef _aws_complete_zones awsR53GetZoneId awsR53GetRecords awsR53GetARecords
compdef _aws_complete_kafka_clusters awsMskFindClusterArnByName awsMskGetConnection awsMskGetZkConnection

compdef _aws_complete_asg awsAsgCheckExistence awsAsgGetTags awsAsgGetRefreshes awsAsgGetActiveRefresh awsAsgRefresh

compdef _aws_complete_eks_clusters awsEksListNodegroups awsEksUpdateNodegroups awsEksRegisterCluster
compdef _aws_complete_eks_nodegroups awsEksUpdateNodegroup awsEksWaitForNodeGroupActive
