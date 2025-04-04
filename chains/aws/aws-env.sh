export CHI_CLOUD_AWS_ENV_INIT=false
export CHI_CLOUD_AWS_AUTH_INIT=false

function awsInitAuth() {
    [[ $CHI_CLOUD_AWS_ENV_INIT = "true" ]] && return 0

    # set google username
    local googleUsername=$(chiConfigUserRead cloud aws googleUsername)
    if [[ -z $googleUsername ]]; then
        echo "the user config field 'aws-auth.googleUsername' must be set to your email address"
        return 1
    fi
    export CHI_GOOGLE_USERNAME=$googleUsername

    local departmentRole=$(chiConfigUserRead cloud aws departmentRole)
    export CHI_CLOUD_AWS_DEPT_ROLE=$departmentRole

    export AWS_SDK_LOAD_CONFIG=1
    export AWS_SSO_ORG_ROLE_ARN=arn:aws:iam::${AWS_ORG_IDENTITY_ACCOUNT_ID}:role/${CHI_CLOUD_AWS_DEPT_ROLE}

    export CHI_CLOUD_AWS_ENV_INIT=true
}

function awsInitAutoAuth() {
    # if we're already initialized, we're done
    [[ $CHI_CLOUD_AWS_ENV_INIT = "true" ]] && return 0

    local programmaticAuth=$(chiConfigUserRead cloud aws programmaticAuth)
    if [[ "$programmaticAuth" == 'true' ]]; then
        export CHI_CLOUD_AWS_AUTH_INIT=true
        awsInitProgrammaticAuth
        return 0
    fi

    awsInitAuth

    local automaticAuth=$(chiConfigUserRead cloud aws automaticAuth)
    if [[ "$automaticAuth" == 'true' ]]; then
        export CHI_CLOUD_AWS_AUTH_INIT=true
        awsInitAutomaticAuth
        return 0
    fi
}

function awsInitProgrammaticAuth() {
    local programmaticRole=$(chiConfigUserRead cloud aws programmaticRole)

    # await authorization complete...
    local roleArn=$(awsIamGetRoleArn $programmaticRole 2>/dev/null)
    until [[ ! -z $roleArn ]]; do
        sleep 5
        roleArn=$(awsIamGetRoleArn $programmaticRole)
    done

    aws configure set region $AWS_DEFAULT_REGION
    awsAssumeProgrammaticRoleArn $programmaticRole $roleArn
}

function awsInitAutomaticAuth() {
    local profile=$(chiConfigUserRead cloud aws defaultProfile)
    if [[ -z $profile ]]; then
        chiLogError "automaticAuth enabled, but defaultProfile not set!" cloud aws
        return 1
    fi
    # echo "authorizing $profile..."
    awsAuth $profile
}

# prints your currently-assumed IAM role if authenticated, or fails
function awsRole() {
    local id
    if id=$(awsId); then
        export CHI_CLOUD_AWS_CURRENT_ROLE=$(echo $id | jq '.Arn' | awk -F '/' '{ print $2 }')
        echo $CHI_CLOUD_AWS_CURRENT_ROLE
    else
        return 1
    fi
}

# removes authentication, can be used for testing/resetting
function awsRevoke() {
    cp ~/.aws/credentials ~/.aws/credentials.bak
    echo "[$AWS_ORG_SSO_PROFILE]\n" > ~/.aws/credentials
    awsId
}

function awsOrg() {
    requireArgOptions "an organization name" "$1" "$CHI_KNOWN_AWS_ORGS" || return 1

    export CHI_CLOUD_AWS_DEPT_ROLE="$1"
    echo "Set AWS organization to: $1"
}

# checks if you're authenticated, triggers authentication if not,
# and then assumes the provided role
function awsAuth() {
    awsInitAuth || return 1
    requireArgOptions "a known AWS profile" "$1" "$CHI_KNOWN_AWS_PROFILES" || return 1

    requireArg "a profile name" $1 || return 1

    local mfaCode="$2"
    local mfaArg=$(isSet "$mfaCode" && echo "--mfa-code $mfaCode" || echo '')
    export AWS_PROFILE=$1
    export AWS_SSO_ORG_ROLE_ARN=arn:aws:iam::${AWS_ORG_IDENTITY_ACCOUNT_ID}:role/${CHI_CLOUD_AWS_DEPT_ROLE}

    if ! awsCheckAuth; then
        echo "Authenticating..."
        AWS_PROFILE=$AWS_ORG_SSO_PROFILE gimme-aws-creds --roles $AWS_SSO_ORG_ROLE_ARN $mfaArg
    fi

    local role=$(awsRole)
    echo "Assumed role: $role"
}

# run a command with a specific AWS profile
# args: profile name
function withProfile() {
    awsInitAuth || return 1

    requireArg "a profile name" $1 || return 1
    local profile="$1"
    shift

    requireArg "a command to run" $1 || return 1

    local currentProfile=$(awsRole)

    awsAuth $profile >/dev/null
    $*
    awsAuth $currentProfile >/dev/null
}
