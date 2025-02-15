
function k8sKustomizeGetValuesFiles() {
    requireFileArg "a kustomization file" "$1" || return 1

    yamlFileToJson "$1" | jq -r --arg chart node '.helmCharts[] | select(.name == $chart) | .additionalValuesFiles[]'
}

function k8sKustomizeMergeValuesFiles() {
    requireFileArg "a kustomization file" "$1" || return 1

    jsonMergeDeep $(k8sKustomizeGetValuesFiles "$1" | xargs -I {} yq e -o=json {} | jq -c) | prettyYaml
}
