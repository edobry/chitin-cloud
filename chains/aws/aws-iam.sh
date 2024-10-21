function awsIamListUsers() {
    aws iam list-users | jq -r '.Users[].UserName'
}

function awsIamListRoles() {
    aws iam list-roles | jq -r '.Roles[].RoleName'
}

function awsIamListOwnPolicies() {
    aws iam list-policies --scope Local | jq -r '.Policies[] | "\(.PolicyName) - \(.Arn)"'
}

function awsIamListManagedPolicies() {
    aws iam list-policies --scope AWS | jq -r '.Policies[] | "\(.PolicyName) - \(.Arn)"'
}

# shows all policy attachments for a given role
# args: role name
function awsIamListRolePolicies() {
    requireArg "a role name" $1 || return 1

    aws iam list-attached-role-policies --role-name $1 |\
        jq -cr '.AttachedPolicies[].PolicyArn'
}

# shows all policy attachments for a given user
# args: user name
function awsIamListUserPolicies() {
    requireArg "a role name" $1 || return 1

    aws iam list-attached-user-policies --user-name $1 |\
        jq -cr '.AttachedPolicies[].PolicyArn'
}

# fetches a policy
# args: policy ARN
function awsIamGetPolicy() {
    requireArg "a policy ARN" $1 || return 1

    aws iam get-policy --policy-arn "$1"
}

# shows all policy attachments and their allowed actions for the current role
function awsIamShowCurrentRolePermissions() {
    local role=$(awsRole)

    echo -e "Showing policy attachments for role '$role'...\n"

    awsIamListRolePolicies "$role" | \
    while read -r policyArn; do
        local policyVersion=$(awsIamGetPolicy "$policyArn" | jq -r '.Policy.DefaultVersionId')
        awsIamShowPolicy "$policyArn" "$policyVersion"
        echo
    done
}

# shows all policy attachments for a given policy version
# args: policy ARN, policy version
function awsIamGetPolicyAttachments() {
    requireArg "a policy ARN" $1 || return 1
    requireArg "a policy version" $2 || return 1

    local policyArn="$1"
    local policyVersion="$2"

    aws iam get-policy-version \
        --policy-arn $policyArn --version-id $policyVersion
}

# shows all policy attachments and their allowed actions for a given policy version
# args: policy ARN, policy version
function awsIamShowPolicy() {
    requireArg "a policy ARN" $1 || return 1
    requireArg "a policy version" $2 || return 1

    local policyArn="$1"
    local policyVersion="$2"
    local policyName=$(echo "$policyArn" | awk -F'/' '{ print $2 }')

    local policyAttachments=$(awsIamGetPolicyAttachments $policyArn $policyVersion |\
        jq -cr '.PolicyVersion.Document.Statement[]')

    echo "$policyName $policyVersion"
    echo "==========================="

    echo "$policyAttachments" |\
    while read -r attachment; do
        local header=$(jsonRead "$attachment" '"\(.Effect) \(.Resource)"')
        local actions=$([[ $(jsonRead "$attachment" '.Action') != "*" ]] && jsonRead "$attachment" '.Action[]' || echo "All actions")

        echo "$header"
        echo "---------------------------"
        echo "$actions"
        echo "==========================="
    done
}

function awsIamCreateProgrammaticCreds() {
    requireArg "an IAM role id" "$1" || return 1
    checkAuthAndFail || return 1
    
    local roleArn
    local roleName
    if checkIsArn "$1"; then
        roleArn="$1"
        roleName=$(awsIamGetRoleName "$1")
    else
        roleArn=$(awsIamGetRoleArn "$1")
        roleName="$1"
    fi

    local googleUsername=$(chiReadConfig '.chains["aws-auth"].googleUsername' -r)
    local newIamSuffix="programmatic-tmp-$(randomString 5)"
    local newIamUsername="$googleUsername-$newIamSuffix"

    local createUserOutput
    createUserOutput=$(aws iam create-user --user-name $newIamUsername)
    [[ $? -eq 0 ]] || return 1

    local createKeyOutput
    createKeyOutput=$(aws iam create-access-key --user-name $newIamUsername)
    if [[ $? -ne 0 ]]; then
        awsIamDeleteProgrammaticUser quiet $newIamUsername
        return 1
    fi

    local newIamRole="$roleName-$newIamSuffix"
    local createRoleOutput
    createRoleOutput=$(awsIamCloneRole quiet $roleName $newIamRole)
    if [[ $? -ne 0 ]]; then
        awsIamDeleteProgrammaticUser quiet $newIamUsername
        return 1
    fi

    # echo "authorizing assume role: $newIamRole $newIamUsername" >&2
    awsIamAuthorizeAssumeRole $newIamRole $newIamUsername

    jsonRead "$createKeyOutput" '.AccessKey | { user: .UserName, role: $roleName, id: .AccessKeyId, key: .SecretAccessKey }'\
        --arg roleName $newIamRole
}

function awsIamDeleteProgrammaticCreds() {
    requireJsonArg "of programmatic credentials" "$1" || return 1

    local creds="$1"
    validateJsonFields "$creds" user role || return 1

    awsIamDeleteProgrammaticUser quiet $(jsonRead "$creds" '.user')
    awsIamDeleteRole yes quiet $(jsonRead "$creds" '.role')
}

# args: (optional) "quiet"
function awsIamDeleteProgrammaticUser() {
    requireArg "an IAM user name" "$1" || return 1

    unset quietMode
    if [[ "$1" == "quiet" ]]; then
        quietMode=true
        shift
    fi

    local userName="$1"
    local accessKeyIds=$(awsIamGetAccessKeysForUser $userName)

    if [[ ! -z "$accessKeyIds" ]]; then
        while IFS= read -r keyId; do
            notSet $quietMode && echo "Deleting access key '$keyId'..."
            awsIamDeleteAccessKey $userName "$keyId"
        done <<< "$accessKeyIds"
    fi

    notSet $quietMode && echo "Querying user policies..."
    local policyNames=$(aws iam list-user-policies --user-name $userName | \
        jq -r '.PolicyNames[]')

    while IFS= read -r policyName; do
        notSet $quietMode && echo "Deleting user policy '$policyName'..."
        aws iam delete-user-policy --user-name $userName --policy-name "$policyName"
    done <<< "$policyNames"

    notSet $quietMode && echo "Deleting user '$userName'..."
    aws iam delete-user --user-name $userName
}

function awsIamDeleteAccessKey() {
    requireArg "an IAM user name" "$1" || return 1
    requireArg "an IAM access key id" "$2" || return 1

    aws iam delete-access-key --user-name "$1" --access-key-id "$2"
}

function awsIamGetAccessKeysForUser() {
    requireArg "an IAM user name" "$1" || return 1

    aws iam list-access-keys --user-name "$1" | jq -r '.AccessKeyMetadata[].AccessKeyId'
}

function awsIamCloneRole() {
    requireArg "a source IAM role name" "$1" || return 1
    requireArg "a target IAM role name" "$2" || return 1

    unset quietMode
    if [[ "$1" == "quiet" ]]; then
        quietMode=true
        shift
    fi

    local sourceRoleName="$1"
    local targetRoleName="$2"

    notSet $quietMode && echo "Querying source role policy attachments..."
    local sourcePolicyArns=$(aws iam list-attached-role-policies --role-name $sourceRoleName | \
        jq -r '.AttachedPolicies[].PolicyArn')

    notSet $quietMode && echo "Querying source role assume-role policy document..."
    local sourceAssumeRolePolicyDocumentFile=$(tempFile)
    awsIamGetAssumeRolePolicyDocument $sourceRoleName > $sourceAssumeRolePolicyDocumentFile

    notSet $quietMode && echo "Creating new role '$targetRoleName'..."
    local createOutput
    createOutput=$(aws iam create-role --role-name $targetRoleName \
        --assume-role-policy-document file://$sourceAssumeRolePolicyDocumentFile)
    [[ $? -eq 0 ]] || return 1

    while IFS= read -r policyArn; do
        notSet $quietMode && echo "Attaching policy '$policyArn'..."
        aws iam attach-role-policy --role-name $targetRoleName --policy-arn "$policyArn"
    done <<< "$sourcePolicyArns"
}

function awsIamGetAssumeRolePolicyDocument() {
    requireArg "an IAM role name" "$1" || return 1

    aws iam get-role --role-name "$1" | jq '.Role.AssumeRolePolicyDocument'
}

function awsIamDeleteRole() {
    requireArg "an IAM role name" "$1" || return 1

    if [[ "$1" != 'yes' ]]; then
        echo "This command is potentially destructive; please ensure you're passing the right arguments, and then re-run with 'yes' as the first argument"
        return 0
    else
        shift
    fi

    unset quietMode
    if [[ "$1" == "quiet" ]]; then
        quietMode=true
        shift
    fi

    local roleName="$1"

    notSet $quietMode && echo "Querying role policy attachments..."
    local policyArns=$(awsIamListRolePolicies $roleName)

    while IFS= read -r policyArn; do
        notSet $quietMode && echo "Detaching policy '$policyArn'..."
        aws iam detach-role-policy --role-name $roleName --policy-arn "$policyArn"
    done <<< "$policyArns"

    notSet $quietMode && echo "Deleting role '$roleName'..."
    aws iam delete-role --role-name $roleName
}

function awsIamGetUserArn() {
    requireArg "an IAM user name" "$1" || return 1

    aws iam get-user --user-name "$1" | jq -r '.User.Arn'
}

function awsIamAuthorizeAssumeRole() {
    requireArg "an IAM role name" "$1" || return 1
    requireArg "an IAM user name" "$2" || return 1

    local roleName="$1"
    local userName="$2"

    local roleArn=$(awsIamGetRoleArn $roleName)
    local userArn=$(awsIamGetUserArn $userName)
    local assumeRoleDoc=$(awsIamGetAssumeRolePolicyDocument $roleName)

    local userGetRolePolicy=$(jq -nc \
        --arg roleArn $roleArn \
    '{
        Version: "2012-10-17",
        Statement: [{
            Sid: "AllowGetRole",
            Effect: "Allow",
            Action: [
                "iam:GetRole"
            ],
            Resource: $roleArn
        }, {
            Sid: "AllowListRoles",
            Effect: "Allow",
            Action: [
                "iam:ListRoles"
            ],
            Resource: "*"
        }]
    }')


    aws iam put-user-policy --user-name $userName \
        --policy-document "$userGetRolePolicy" --policy-name AllowGetRolePolicy

    local authzStatement=$(jq -nc --arg userArn $userArn '{
        Sid: "ProgrammaticAssumption",
        Effect: "Allow",
        Principal: {
            AWS: $userArn
        },
        Action: "sts:AssumeRole"
    }')

    local patchedAssumeRoleDoc=$(echo "$assumeRoleDoc" "$authzStatement" |\
        jq -sc '.[1] as $patch | .[0].Statement += [$patch] | .[0]')

    aws iam update-assume-role-policy --role-name $roleName \
        --policy-document $patchedAssumeRoleDoc

    sleep 15
}

function awsIamGetRoleArn() {
    requireArg "an IAM role name" "$1" || return 1

    local result
    result=$(aws iam get-role --role-name "$1" | jq -r '.Role.Arn')
    [[ $? -eq 0 ]] || return 1

    echo "$result"
}

function checkIsArn() {
    [[ "$1" == "arn:aws:"* ]]
}

# checks that an argument is supplied and that it is an AWS ARN
# args: name of arg, arg value
function requireArnArg() {
    requireArgWithCheck "$1" "$2" checkIsArn "an AWS "
}

function awsIamGetRoleName() {
    requireArnArg "IAM role arn" "$1" || return 1

    aws iam list-roles --query "Roles[?Arn==\`$1\`]" | jq -r '.[].RoleName'
}

function awsIamAssumeRole() {
    requireArg "an IAM role id" "$1" || return 1

    local roleArn
    local roleName
    if checkIsArn "$1"; then
        roleArn="$1"
        roleName=$(awsIamGetRoleName "$1")
    else
        roleArn=$(awsIamGetRoleArn "$1")
        roleName="$1"
    fi

    if [[ $? -ne 0 ]]; then
        echo "$roleArn"
        echo "Could not assume programmatic role '$1'!"
        return 1
    fi

    aws sts assume-role --role-arn $roleArn \
        --role-session-name "programmatic-session-$(randomString 3)"
}

# assumes an IAM role in a subshell, can be used to test permissions
# args: IAM role name
function awsIamAssumeRoleShell() {
    requireArg "an IAM role id" "$1" || return 

    local awsCreds
    awsCreds=$(awsIamAssumeRole "$1")
    if [[ $? -ne 0 ]]; then
         echo $awsCreds
         return 1
     fi

    echo "Starting subshell as role '$1'..."
    AWS_ACCESS_KEY_ID="$(jsonRead "$awsCreds" '.Credentials.AccessKeyId')" \
        AWS_SECRET_ACCESS_KEY="$(jsonRead "$awsCreds" '.Credentials.SecretAccessKey')" \
        AWS_SESSION_TOKEN="$(jsonRead "$awsCreds" '.Credentials.SessionToken')" \
        bash --init-file <(echo "source $CA_DT_DIR/init.sh;\
            echo 'subshell initialized';")

    echo "Exiting assumed role '$1' session"
}

# assumes an IAM role in a subshell, can be used to test permissions
# args: IAM role name
function awsIamAssumeProgrammaticRoleShell() {
    requireArg "an IAM role id" "$1" || return 

    echo "Creating programmatic credentials for role '$1'..."
    local awsCreds
    awsCreds=$(awsIamCreateProgrammaticCreds "$1")
    if [[ $? -ne 0 ]]; then
         echo $awsCreds
         return 1
     fi

    echo "Starting subshell as programmatic user '$(jsonRead "$awsCreds" '.user')'..."
    AWS_ACCESS_KEY_ID="$(jsonRead "$awsCreds" '.id')" \
    AWS_SECRET_ACCESS_KEY="$(jsonRead "$awsCreds" '.key')" \
        bash --init-file <(echo "source $CA_DT_DIR/init.sh;\
        awsIamAssumeRoleShell $(jsonRead "$awsCreds" '.role');")
    
    echo "Cleaning up session..."
    awsIamDeleteProgrammaticCreds "$awsCreds"
}
