function awsAsgList() {
    aws autoscaling describe-auto-scaling-groups | jq -r '.AutoScalingGroups[].AutoScalingGroupName'
}

# checks the existence of an ASGwith the given name
# args: ASG name
function awsAsgCheckExistence() {
    requireArg "an ASG name" $1 || return 1

    aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$1" | jq -e '.AutoScalingGroups[]' >/dev/null 2>&1
}


# gets the tags for the ASG with the given name
# args: ASG name
function awsAsgGetTags() {
    requireArg "an ASG name" "$1" || return 1

    aws autoscaling describe-auto-scaling-groups | jq -r --arg asgName "$1" \
        '.AutoScalingGroups[] | select(.AutoScalingGroupName == $asgName) | .Tags[] | "\(.Key): \(.Value)"'
}

function awsAsgGetActiveRefresh() {
    requireArg "an ASG name" "$1" || return 1

    awsAsgGetRefreshes "$1" | jq -re \
        '.InstanceRefreshes[] | select(.Status == "InProgress" or .Status == "Cancelling" ).InstanceRefreshId'
}

function awsAsgGetRefreshes() {
    requireArg "an ASG name" "$1" || return 1

    aws autoscaling describe-instance-refreshes \
        --auto-scaling-group-name "$1" $(isSet "$2" && echo "--instance-refresh-ids $2" || echo "") | jq -c
}

function awsAsgCancelRefresh() {
    requireArg "an ASG name" "$1" || return 1
    
    local inProgressRefresh=$(awsAsgGetActiveRefresh "$1")
    isSet "$inProgressRefresh" || return 0

    echo "ASG instance refresh '$inProgressRefresh' already in progress; cancelling"
    aws autoscaling cancel-instance-refresh --auto-scaling-group-name "$1" >/dev/null
    
    local refreshProgress
    until refreshProgress=$(awsAsgGetRefreshes "$1" "$inProgressRefresh") && \
      echo "$refreshProgress" | jq -r '.InstanceRefreshes[0].Status' \
      | grep -qm 1 "Cancelled";
    do
        echo "Waiting..."
        sleep 10;
    done

    echo "ASG '$1' refresh has been cancelled successfully!"

}

function awsAsgRefresh() {
    requireArg "an ASG name" "$1" || return 1

    if ! awsAsgCheckExistence $1; then
        echo "No ASG with the given name found!"
        return 1
    fi

    awsAsgCancelRefresh "$1"

    echo "Starting instance refresh for ASG '$1'..."
    local refreshResult
    refreshResult=$(aws autoscaling start-instance-refresh --auto-scaling-group-name "$1" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "Something went wrong refreshing the ASG!"
        echo "$refreshResult"
        return 1
    fi

    local refreshId=$(jsonRead "$refreshResult" .InstanceRefreshId)

    local refreshProgress
    until refreshProgress=$(awsAsgGetRefreshes "$1" "$refreshId") && \
      echo "$refreshProgress" | jq -r '.InstanceRefreshes[0].Status' \
      | grep -qm 1 "Successful";
    do
        echo "Waiting... $(jsonRead "$refreshProgress" '.InstanceRefreshes[0].PercentageComplete // 0')% complete"
        sleep 10;
    done

    echo "ASG '$1' has been refreshed successfully!"
}
