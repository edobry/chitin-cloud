# lists all hosted zones
function awsR53ListZones() {
    chiCloudPlatformCheckAuthAndFail || return 1

    aws route53 list-hosted-zones | jq -r '.HostedZones[] | "\(.Id) \(.Name)"'
}

# finds the id of the Route 53 hosted zone the given name
# args hosted zone name
function awsR53GetZoneId() {
    requireArg "a hosted zone name" "$1" || return 1

    local zoneId=$(aws route53 list-hosted-zones-by-name \
        --dns-name "$1" | jq -r '.HostedZones[]?.Id')
    [[ -z "$zoneId" ]] && return 1

    echo "$zoneId"
}

# gets all records in the given hosted zone in JSON format
# args: hosted zone identifier
function awsR53GetRecordsJson() {
    requireArg 'a hosted zone ID' "$1" || return 1
    chiCloudPlatformCheckAuthAndFail || return 1

    local zoneId=$([[ "$1" == "/hostedzone/"* ]] && echo "$1" || awsR53GetZoneId "$1")
    if [[ -z $zoneId ]]; then
        echo "Hosted zone not found!"
        return 1
    fi

    aws route53 list-resource-record-sets --hosted-zone-id "$zoneId" | jq -c '.ResourceRecordSets'
}

# gets all records in the given hosted zone
# args: hosted zone identifier
function awsR53GetRecords() {
    local records
    records=$(awsR53GetRecordsJson "$1")
    if [[ $? -ne 0 ]]; then
        echo "$records"
        return 1
    fi

    echo "$records" | jq -jr \
        '.[] | {
            name: "\(.Type) \(.Name)",
            records: (.ResourceRecords[]?.Value // .AliasTarget?.DNSName)
        } | "\(.name)\n\(.records)\n\n"'
}

# gets all A records in the given hosted zone
# args: hosted zone identifier
function awsR53GetARecords() {
    local records
    records=$(awsR53GetRecordsJson "$1")
    if [[ $? -ne 0 ]]; then
        echo "$records"
        return 1
    fi

    echo "$records" | jq -r \
        '.[] | select(.Type == "A") | {
            name: .Name,
            value: ([
                .ResourceRecords[]?.Value,
                .AliasTarget?.DNSName
            ][] | select(. != null))
        } | "\(.name) - \(.value)"'
}

# gets all TXT records in the given hosted zone matching a query
# args: hosted zone identifier
function awsR53QueryTxtRecords() {
    requireArg 'a hosted zone ID' "$1" || return 1
    requireArg 'a record query' "$2" || return 1

    local records="$3"
    # echo "testing: $3"
    if [[ -z "$3" ]]; then
        records=$(awsR53GetRecordsJson "$1")
        if [[ $? -ne 0 ]]; then
            echo "$records"
            return 1
        fi
    fi

    # echo "in txt records"
    # echo "$records"

    echo "$records" | jq -cr \
        "[.[] | select(.Type == \"TXT\" and \
            any(.ResourceRecords[].Value; . | $2))]"
}
