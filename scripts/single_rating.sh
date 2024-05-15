#!/bin/bash

cwd="$(dirname "$(readlink -f "$0")")"

mysqljb() {
	mysql -D jailbreak_research --skip-column-names --batch -e "$1"
}

# Initialize variables
ps=""
mq=""
rid=""
judge="glm-4"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
	case $1 in
	-ps)
		ps="$2"
		shift
		;;
	-mq)
		mq="$2"
		shift
		;;
	-r | -rid)
		rid="$2"
		shift
		;;
	-j | --judge)
		judge="$2"
		shift
		;;
	*)
		echo "Unknown parameter passed: $1"
		exit 1
		;;
	esac
	shift
done

# Check if mandatory arguments are provided
if [[ -z "$ps" || -z "$mq" || -z "$r" ]]; then
	echo "Missing required arguments"
	echo "Usage: $0 -ps <ps_id> -mq <mq_id> -r <response_id> [-j <judge>]"
	exit 1
fi

api_url=$(mysqljb "select api_url from judges where name='$judge'")
api_key=$(mysqljb "select ak from api_keyss where name='$judge' and available=true limit 1")
question=$(mysqljb "select mq from malicious_questions where ps_id=$ps and mq_id=$mq")
response=$(mysqljb "select response from responses where response_id=$rid")

$cwd/api_helper.sh --rpt-id 1 --model "$judge" -t 0.1 -mt 5 -sp "$question" -up "$response" -ak "$api_key" -ah "$api_url"
