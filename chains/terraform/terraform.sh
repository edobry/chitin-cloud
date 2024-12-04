# generates a terraform plan and shows destructive actions. can specify a module or call from inside one.
# args: terraform environment (optional), module (optional)
function tfShowDestroys() {
    checkAuthAndFail || return 1

    requireArg "a TF repo" $1 || return 1
    requireArg "a TF environment" $2 || return 1
    requireArg "a TF module" $3 || return 1

    local tfRepo="$1"
    local tfEnv="$2"
    local module="$3"

    local tfCommand
    if ! [[ -z $1 ]]; then
        tfCommand=("tfRun" "$tfRepo" "$tfEnv" "$module")
    elif [[ -f $PWD/main.tf ]]; then
        tfCommand=("terraform")
    else
        echo "Please enter into or specify a Terraform module!"
        return 1;
    fi

    local planFile="/tmp/tfplan-$(randomString 5)"

    echo "Generating plan..."

    "${tfCommand[@]}" plan -out "$planFile" > /dev/null
    local planJson=$("${tfCommand[@]}" show -json "$planFile")

    local destroys=$(jq -r '.resource_changes[] | select(.change.actions[0] == "delete") | .address' <<< "$planJson")
    if [[ -z $destroys ]]; then
        echo "No destructive actions planned."
    else
        echo "Resources to be destroyed:"

        echo $destroys
    fi

    rm $planFile
}

# locks a specific TG remote state
# operates on the module in the working dir
function tgLock() {
    checkAuthAndFail || return 1
    
    echo 'Locking state...'
    local workingDir=$(tgGetWorkingDir)
    pushd $workingDir > /dev/null
    tflock > /dev/null
    popd > /dev/null
    echo 'State locked!'
}

# unlocks a specific TG remote state
# operates on the module in the working dir
function tgUnlock() {
    checkAuthAndFail || return 1
    
    local lockId=$(tgGetLockId)
    if [[ -z "$lockId" ]]; then
        echo "Could not detect lock id! Might already be unlocked?"
        return 1
    fi

    echo "Unlocking lock ID: ${lockId}..."
    terragrunt force-unlock -force "$lockId"
}

function tfClearCache() {
    requireArg "a TF repository" "$1" || return 1

    if [[ "$1" != 'yes' ]]; then
        echo "This command is potentially destructive; please ensure you're passing the right path, and then re-run with 'yes' as the first argument"
        return 0
    else
        shift
    fi

    local repoPath="$CHI_PROJECT_DIR/$1"

    if [[ ! -d $repoPath ]]; then
        echo "Directory '$repoPath' does not exist!"
        return 1
    fi

    pushd $repoPath > /dev/null

    echo "Clearing Terragrunt cache..."
    find . -type d -name ".terragrunt-cache" -prune -print -exec rm -rf {} \;

    echo "Clearing Terraform cache..."
    find . -type d -name ".terraform" -prune -print -exec rm -rf {} \;

    popd > /dev/null
}

# convert a terraform module source to a local path
# args: TF module source url
function tfSourceToLocal() {
    requireArg "a TF module source URL" "$1" || return 1

    echo "$1" | sed "s/git@github.com:[a-zA-Z]*\//$(echo $CA_PROJECT_DIR | escapeSlashes)\//" | sedStripGitEx | sedStripRef
}

# reads the terragrunt module source
# args: terragrunt config
function tgGetSource() {
    local filePath="$1"
    local tgFile='terragrunt.hcl'
    if ! isSet "$1"; then
        if [[ ! -f $tgFile ]]; then
            echo 'no Terragrunt configuration found!'
            return 1
        fi
        filePath="$PWD/$tgFile"
    fi

    hcl2json "$filePath" | jq -r '.terraform[].source'
}

# converts the terragrunt module source to a local path
# args: terragrunt config
function tgSourceToLocal() {
    local sourcePath
    sourcePath=$(tgGetSource "$1")
    if [[ $? -ne 0 ]]; then
        echo "$sourcePath"
        return 1
    fi

    tfSourceToLocal "$sourcePath"
}

# navigates to the terragrunt source module locally
# args: terragrunt config
function tgGoToLocalSource() {
    echo "navigating to Terraform module, use 'popd' to return"
    local sourcePath
    sourcePath=$(tgSourceToLocal "$1")
    if [[ $? -ne 0 ]]; then
        echo "$sourcePath"
        return 1
    fi

    pushd "$sourcePath" >/dev/null
}

function tfFormatSubdirs() {
    for d in ./*/ ; do (cd "$d" && terraform fmt); done
}

function tfValidateSubdirs() {
    for d in ./*/; do (
        chdir "$d";
        if [[ ! -f ".validation-exclude" ]]; then
            echo "valdiating '$d'...";
            terraform validate;
        fi;
    ) done
}

function tgMigrate() {
    requireArg "a tfmigrate command" "$1" || return 1
    requireArg "a tfmigrate migration file" "$2" || return 1

    TFMIGRATE_LOG=DEBUG TFMIGRATE_EXEC_PATH=terragrunt tfmigrate $1 $2
}

function tgGetWorkingDir() {
    terragrunt terragrunt-info | jq -r '.WorkingDir'
}

function tfClearLocks() {
    deleteFiles .terraform.lock.hcl
}

function tfParseLockId() {
    grep 'ID:' | sed 's/ *ID\: *//'
}

function tfGetLockId() {
    terraform plan -no-color -input=false 2>&1 | tfParseLockId
}

function tgGetLockId() {
    terragrunt plan -no-color -input=false 2>&1 | tfParseLockId
}
