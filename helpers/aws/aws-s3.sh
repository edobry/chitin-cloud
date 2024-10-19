# lists existing S3 buckets
function awsS3ListBuckets() {
    checkAuthAndFail || return 1

    aws s3api list-buckets | jq -r '.Buckets[].Name'
}

# lists permissions for an S3 bucket
# args: bucket name, principal (optional)
function awsS3BucketPermissions() {
    checkAuthAndFail || return 1

    requireArg "a bucket name" "$1" || return 1

    local permissions=$(aws s3api get-bucket-policy --bucket "$1" | jq -r '.Policy' | jq -rc '.Statement[]')
    if [[ -z "$2" ]]; then
        echo "$permissions"
    else
        echo "$permissions" | jq -r --arg principal "$2" 'select(.Principal == "*" or .Principal.AWS == $principal)'
    fi
    
}

# list objects in bucket
function awsS3ListBucketObjects() {
    checkAuthAndFail || return 1

    requireArg "a bucket name" "$1" || return 1
    local prefixArg=$([[ ! -z "$2" ]] && echo " --prefix $2" || echo '')

    aws s3api list-objects --bucket "$1"$prefixArg | jq -r '.Contents[].Key'
}

# downloads and reads the content of a particular S3 object
# args: S3 key
function awsS3ReadObject() {
    checkAuthAndFail || return 1

    requireArg "an S3 path" $1
    local s3Path="$1"
    local localPath=$(tempFile)

    aws s3 cp --quiet $s3Path $localPath
    cat $localPath
}

# check if the given key in the given s3 bucket exists
# args: bucket, key
function awsS3KeyExists() {
    checkAuthAndFail || return 1

    requireArg "a bucket name" "$1" || return 1
    requireArg "a key" "$2" || return 1

    aws s3api head-object --bucket "$1" --key "$2" > /dev/null 2>&1
}
