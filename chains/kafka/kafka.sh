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
