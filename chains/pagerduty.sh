export CA_SLACK_WORKSPACE_ID=T04CGLUB1

function pdGetToken() {
    local parameterName=$(chiConfigUserReadField pagerduty parameterName)
    awsSsmGetParam "$parameterName"
}

function pdGetSlackConnections() {
    checkAuthAndFail || return 1

    curl -s --request GET \
        --url https://app.pagerduty.com/integration-slack/workspaces/$CA_SLACK_WORKSPACE_ID/connections \
        --header 'Accept: application/vnd.pagerduty+json;version=2' \
        --header "Authorization: Token token=$(pdGetToken)" \
        --header 'Content-Type: application/json'
}

function pdListSlackConnections() {
     pdGetSlackConnections | jq -r '.slack_connections[] | "\(.source_name) - \(.id) - \(.channel_name)"'
}

function pdGetSlackConnectionId() {
    requireArg "an environment name"  "$1" || return 1
    requireArg "a service name"  "$2" || return 1
    
    pdGetSlackConnections | jq -r --arg source "$1 - $2" '.slack_connections[] | select(.source_name == $source) | .id'
}
