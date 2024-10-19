# args: key ARN, plaintext
function awsKmsEncrypt() {
    requireArg "a key ID" "$1" || return 1
    requireArg "plaintext" "$2" || return 1

    aws kms encrypt --key-id "$1" --plaintext "$2" --output text | awk '{ print $1; }';
}

function awsKmsKeyGetPolicy() {
    requireArg "a key ID" "$1" || return 1
    requireArg "a key policy name" "$2" || return 1

    aws kms get-key-policy --key-id "$1" --policy-name "$2" | jq -r '.Policy'
}

function awsKmsKeyGetDefaultPolicy() {
    requireArg "a key ID" "$1" || return 1

    awsKmsKeyGetPolicy "$1" default
}
