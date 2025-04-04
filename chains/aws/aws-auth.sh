# prints your full identity if authenticated, or fails
function awsId() {
    local id
    if id=$(aws sts get-caller-identity) 2> /dev/null; then
        echo $id
    else
        return 1
    fi
}

# prints your account alias if authenticated, or fails
function awsAccount() {
    local id
    if id=$(aws iam list-account-aliases | jq -r '.AccountAliases[0]') 2> /dev/null; then
        echo $id
    else
        return 1
    fi
}

# prints your account alias if authenticated, or fails
function awsAccountName() {
    awsAccount 2>/dev/null | sed 's/ca-aws-//'
}

# prints your account id if authenticated, or fails
function awsAccountId() {
    local id
    if id=$(awsId | jq -r '.Account') 2>/dev/null; then
        echo $id
    else
        return 1
    fi
}

function awsCheckAuth() {
    awsId > /dev/null 2>&1; then
}

# checks if you're authenticated with a specific account, or fails. meant to be used as a failfast
function awsCheckAccountAuthAndFail() {
    chiCloudPlatformCheckAuthAndFail || return 1
    requireArg "an account name" $1 || return 1

    if [[ $(awsAccount) != "$$1" ]]; then
        echo "you are authenticated with the wrong account; please re-authenticate with '$targetAccount'"
        return 1
    fi
}

function awsGetRegion() {
    aws configure get region
}

#fragile, may be better way? potentially to query with aws cli and filter
function awsGetRegionForAz() {
    echo "$1" | sed 's/\(.*\)[a-z]/\1/'
}

function awsShowEnvvars() {
    env | grep 'AWS_' | grep -v "CA_"
}
