function kafkacatd() {
    docker run -it --rm edenhill/kafkacat:1.5.0 kafkacat -b $*
}

# args: broker url
function kafkaListTopics() {
    requireArg "a broker URL" $1 || return 1

    kafkacatd $1 -L | grep "topic \"" | awk '{ print $2 }' | sed 's/\"//g'
}

# reads a specific topic from an offset
# args: broker url, topic name, offset from end
function kafkaReadTopic() {
    requireArg "a broker URL" "$1" || return 1
    requireArg "a topic name" "$2" || return 1
    requireNumericArg "offset" "$3" || return 1

    kafkacatd $1 -C -t $2 -o -$3 -qe
}

# resets an MSK cluster's topics by destroying and recreating using terraform
# args: TF repo, TF environment, cluster name
function kafkaResetTopics() {
    checkAuthAndFail || return 1

    requireArg "a TF repo" "$1" || return 1
    requireArg "a TF environment" "$2" || return 1
    requireArg "an MSK cluster name" "$3" || return 1

    local topicsModule="$3-topics"

    echo "Resetting topics in '$topicsModule'..."

    runTF $1 $2 $topicsModule destroy -auto-approve
    runTF $1 $2 $topicsModule apply -auto-approve
}
