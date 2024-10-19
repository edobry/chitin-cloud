export CHI_CA_AWS_ENV_INIT=false
export CHI_CA_AWS_AUTH_INIT=false

export CHI_CA_AWS_CONFIG_ROOT=$CHI_CA_DIR/shell/terraform
export CHI_CA_AWS_CONFIG_PATH=util/aws/config
export CHI_CA_AWS_CONFIG=$CHI_CA_AWS_CONFIG_ROOT/$CHI_CA_AWS_CONFIG_PATH

function awsAuthChainInit() {
    chiChainCheckBoolean aws envEnabled
}

awsAuthChainInit || return 0

function awsAuthInit() {
    # if we're already initialized, we're done
    ([[ $CHI_CA_AWS_ENV_INIT = "true" ]] && [[ -f $CHI_CA_AWS_CONFIG ]]) && return 0

    # set google username

    local googleUsername=$(chiReadChainConfig aws '.googleUsername // empty')
    if [[ -z $googleUsername ]]; then
        echo "The DT config field aws-auth.googleUsername must be set to your Chainalysis email address."
        return 1
    fi
    export CA_GOOGLE_USERNAME=$googleUsername

    local departmentRole=$(chiReadChainConfig aws '.departmentRole // empty')
    export CA_DEPT_ROLE=$departmentRole

    export AWS_SDK_LOAD_CONFIG=1
    export AWS_SSO_ORG_ROLE_ARN=arn:aws:iam::${AWS_ORG_IDENTITY_ACCOUNT_ID}:role/${CA_DEPT_ROLE}

    export TF_VAR_aws_sessionname=${CA_GOOGLE_USERNAME}

    awsAuthLoadAccounts
    export AWS_CONFIG_FILE=$CHI_CA_AWS_CONFIG

    export CHI_CA_AWS_ENV_INIT=true
}

function awsAuthLoadAccounts() {
    # download generated AWS config
    gitSparseCheckout git@github.com:chainalysis/terraform.git $CHI_CA_AWS_CONFIG_ROOT $CHI_CA_AWS_CONFIG_PATH
    
    awsAuthDetectProfiles
}

# set known accounts & profiles
function awsAuthDetectProfiles() {
    export CA_KNOWN_AWS_PROFILES=$(cat $CHI_CA_AWS_CONFIG | pcregrep -o1 '\[profile ([a-zA-Z0-9\-]*)' | replaceNewlines)
    export CA_KNOWN_AWS_ACCOUNTS=$(echo $CA_KNOWN_AWS_PROFILES | splitOnSpaces | sed -E 's/-(admin|poweruser|readonly|secadmin|secaudit|sysadmin)*$//' | uniq | replaceNewlines)
}

function awsAuthUpdateAccounts() {
    if [[ ! -d $CHI_CA_AWS_CONFIG_ROOT ]]; then
        awsAuthLoadAccounts
        return
    fi
    
    gitPullMain $CHI_CA_AWS_CONFIG_ROOT hard
    awsAuthDetectProfiles
}

function initAutoAwsAuth() {
    # if we're already initialized, we're done
    [[ $CHI_CA_AWS_ENV_INIT = "true" ]] && return 0

    local programmaticAuth=$(chiReadChainConfig aws '.programmaticAuth')
    if [[ "$programmaticAuth" == 'true' ]]; then
        export CHI_CA_AWS_AUTH_INIT=true
        awsInitProgrammaticAuth
        return 0
    fi

    awsAuthInit

    local automaticAuth=$(chiReadChainConfig aws '.automaticAuth')
    if [[ "$automaticAuth" == 'true' ]]; then
        export CHI_CA_AWS_AUTH_INIT=true
        awsInitAutomaticAuth
        return 0
    fi
}

function awsInitProgrammaticAuth() {
    local programmaticRole=$(chiReadChainConfig aws '.programmaticRole')

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
    local profile=$(chiReadChainConfig aws '.defaultProfile//empty')
    if [[ -z $profile ]]; then
        dtLog "automaticAuth enabled, but defaultProfile not set!"
        return 1
    fi
    # echo "authorizing $profile..."
    awsAuth $profile
}

# prints your currently-assumed IAM role if authenticated, or fails
function awsRole() {
    local id
    if id=$(awsId); then
        export CA_AWS_CURRENT_ROLE=$(echo $id | jq '.Arn' | awk -F '/' '{ print $2 }')
        echo $CA_AWS_CURRENT_ROLE
    else
        return 1
    fi
}

# removes authentication, can be used for testing/resetting
function deAuth() {
    cp ~/.aws/credentials ~/.aws/credentials.bak
    echo "[$AWS_ORG_SSO_PROFILE]\n" > ~/.aws/credentials
    awsId
}

function awsOrg() {
    requireArgOptions "an organization name" "$1" "$CA_KNOWN_AWS_ORGS" || return 1

    export CA_DEPT_ROLE="$1"
    echo "Set AWS organization to: $1"
}

# checks if you're authenticated, triggers authentication if not,
# and then assumes the provided role
function awsAuth() {
    awsAuthInit || return 1
    requireArgOptions "a known AWS profile" "$1" "$CA_KNOWN_AWS_PROFILES" || return 1

    requireArg "a profile name" $1 || return 1

    local mfaCode="$2"
    local mfaArg=$(isSet "$mfaCode" && echo "--mfa-code $mfaCode" || echo '')
    export AWS_PROFILE=$1
    export AWS_SSO_ORG_ROLE_ARN=arn:aws:iam::${AWS_ORG_IDENTITY_ACCOUNT_ID}:role/${CA_DEPT_ROLE}

    if ! checkAuth; then
        echo "Authenticating..."
        AWS_PROFILE=$AWS_ORG_SSO_PROFILE gimme-aws-creds --roles $AWS_SSO_ORG_ROLE_ARN $mfaArg
    fi

    local role=$(awsRole)
    echo "Assumed role: $role"
}

# run a command with a specific AWS profile
# args: profile name
function withProfile() {
    awsAuthInit || return 1

    requireArg "a profile name" $1 || return 1
    local profile="$1"
    shift

    requireArg "a command to run" $1 || return 1

    local currentProfile=$(awsRole)

    awsAuth $profile >/dev/null
    $*
    awsAuth $currentProfile >/dev/null
}
