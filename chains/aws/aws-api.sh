CA_DT_AWS_CLOUDTRAIL_API_TRAIL='api-debug'

function awsApiStartLogging() {
    aws cloudtrail start-logging --name $CA_DT_AWS_CLOUDTRAIL_API_TRAIL
}

function awsApiStopLogging() {
    aws cloudtrail stop-logging --name $CA_DT_AWS_CLOUDTRAIL_API_TRAIL
}

function awsApiDebugRequest() {
    requireArg 'request ID' "$1" || return 1

    local trail=$(aws cloudtrail get-trail --name $CA_DT_AWS_CLOUDTRAIL_API_TRAIL | jq -c)

    local logGroupName=$(jsonRead "$trail" '.Trail.CloudWatchLogsLogGroupArn' | cut -d ':' -f 7)
    aws logs filter-log-events --log-group-name $logGroupName --filter-pattern "$1" |\
        jq '.events[].message | fromjson'
}
