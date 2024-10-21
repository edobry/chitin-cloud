## depends on: meta, json, docker

function chiDockerBuild() {
    pushd $CHI_PROJECT_DIR/chitin > /dev/null
    local imageHash=$(dockerBuild)
    popd > /dev/null

    echo $imageHash
}

function chiDockerShellBuild() {
    chiDockerShellRun $(chiDockerBuild)
}

function chiDockerShellLatest() {
    chiDockerShellRun $(dockerGetLatestBuild)
}

function chiDockerShell() {
    dockerCheckAndFail || return 1

    local chiVersion="${1:-$(chiGetVersion)}"
    local imageName="$(whoami)/chitin"
    local fullImageName=$(dockerMakeImageName $imageName)

    local imageId="$fullImageName:$chiVersion"
    if ! (
        dockerCheckImageExistsLocal $fullImageName $chiVersion ||\
        dockerCheckImageExistsRemote $imageName $chiVersion
    ); then
        if [[ ! -z $1 ]]; then
            echo "No image found for '$imageId'!"
            return 1
        else
            echo "Building local version..."
            hr
            imageId=$(chiDockerBuild)
            docker tag $imageId $fullImageName:$chiVersion
            hr
        fi
    fi

    chiDockerShellRun $imageId
}

function chiDockerShellRun() {
    requireArg "an image identifier" "$1" || return 1
    checkAuthAndFail || return 1

    local imageId="$1"

    echo "Generating temporary AWS credentials..."
    local awsCreds
    awsCreds=$(awsIamAssumeRole $(awsRole))
    if [[ $? -ne 0 ]]; then
         echo $awsCreds
         return 1
     fi

    local chiConfigFile=$(tempFile)
    jsonReadFile $(chiGetLocation)/docker-config.json5 -n \
        'inputs * {
            chains: {
                "aws-auth": { enabled: true },
                "k8s-env": { enabled: true }
            }
        }' > $chiConfigFile

    # hack to read the helm env output
    eval $(helm env | grep HELM_REPOSITORY_CONFIG)

    echo "Running chitin Docker shell..."
    hr
    docker run -it \
        -e AWS_ACCESS_KEY_ID="$(jsonRead "$awsCreds" '.Credentials.AccessKeyId')" \
        -e AWS_SECRET_ACCESS_KEY="$(jsonRead "$awsCreds" '.Credentials.SecretAccessKey')" \
        -e AWS_SESSION_TOKEN="$(jsonRead "$awsCreds" '.Credentials.SessionToken')" \
        -e AWS_DEFAULT_REGION=$(awsGetRegion) \
        -v $chiConfigFile:/home/chitin/.config/chitin/config.json5:rw \
        -v $HELM_REPOSITORY_CONFIG:/home/chitin/.config/helm/repositories.yaml:ro \
        -v $(pwd):/home/chitin/working-dir:rw \
        $imageId bash
    hr
}
