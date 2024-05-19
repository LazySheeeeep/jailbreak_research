#!/bin/bash

# Default values
api_host="http://ws2.csie.ntu.edu.tw:3795"
api_key="no-key"
model="gpt-3.5-turbo"
system_prompt="You are a helpful assistant. You can help me by answering my questions. You can also ask me questions."
user_prompt="Hi!"
max_tokens=500
temperature=0.7
instruction_template=
out_file=""
request_times=1
#concurrent=false
append_mode=false
starting_index=0
rpt_id=0
mute=false
debug=false

mysqljb() {
	mysql -D jailbreak_research --skip-column-names --batch -e "$1"
}

display_help() {
	cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -ah,  --api-host            Set the API host (default: $api_host)
  -k,   --api-key             Set the API key (default: $api_key)
  --model                     Set the model name (default: $model)
  -spf, --system-prompt-file  Set the system prompt from a file, no default
  -sp,  --system-prompt       Set the system prompt directly as a string (default: $system_prompt)
  -upf, --user-prompt-file    Set the user prompt from a file, no default
  -up,  --user-prompt         Set the user prompt directly as a string (default: $user_prompt)
  -mt,  --max-tokens          Set the maximum number of tokens in the response (default: $max_tokens)
  -t,   --temperature         Set the temperature for response generation (default: $temperature)
  -o,   --out-file            Set the output file (default: command line)
  -rt,  --request-times       Set the number of concurrent requests (default: $request_times)
  -c,   --concurrent-request  Send requests concurrently (default: $concurrent)
  -a,   --append-mode         Append multiple responses to the same output file (default: $append_mode)
  -si,  --starting-index      Set the starting index for output file names (default: $starting_index)
  -it, --instruction-template Set the name of the instruction template, no default value.
  --rpt-id                    Rating prompt template id: rate the response in user prompts, using system prompt as
                              OBJECTIVE, with default rating prompt recognized by rpt id.
                              (default)0: rating mode disabled
  --mute                      Mute the echo (default: $mute)
  -d,   --debug               Enable debug mode, dump the curl message and the response (default: $debug)
  -h,   --help                Display this help message
EOF
}

fit_into_json() {
	local temp="${1//\\/}"
	sed -e 's/\r//g' -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' <<<"${temp//\"/\\\"}"
}

get_response() {
	local json_data='{
  "model": "'$model'",
  "messages": [
    {
      "role": "system",
      "content": "'"$system_prompt"'"
    },
    {
      "role": "user",
      "content": "'"$user_prompt"'"
    }
  ],
  "max_tokens": '$max_tokens',
  "temperature": '$temperature
	if [ -n "$instruction_template" ]; then
		json_data+=', "instruction_template": "'$instruction_template'"'
	fi
	json_data+='}'
	if [[ ! "$api_host" =~ "chat/completions" ]]; then
		api_host="$api_host/v1/chat/completions"
	fi
	if $debug; then
		echo "curl -s "$api_host" -H "Content-Type: application/json" -H "Authorization: Bearer $api_key" -d "$json_data"" >&2
	fi
	response_raw=$(curl -s "$api_host" -H "Content-Type: application/json" -H "Authorization: Bearer $api_key" -d "$json_data")
	if $debug; then
		echo "$response_raw" >&2
	fi
	local msg_content=$(echo "$response_raw" | jq -r '.choices[0].message.content')
	if [ "$msg_content" == "null" ] || [ -z "$response_raw" ]; then
		echo -e "\nError: Something went wrong from $api_host. Got this:\n$response_raw" >&2
		exit 1
	fi
	echo "$msg_content" | sed -e ':a' -e 'N' -e '$!ba' -e 's/^\n*//g'
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-ah | --url | --api-host)
		shift
		api_host="$1"
		;;
	--model)
		shift
		model="$1"
		;;
	-k | -ak | --key | --api-key)
		shift
		api_key="$1"
		;;
	-spf | --system-prompt-file)
		shift
		system_prompt=$(fit_into_json "$(cat "$1")")
		;;
	-sp | --system-prompt)
		shift
		system_prompt=$(fit_into_json "$1")
		;;
	-upf | --user-prompt-file)
		shift
		user_prompt=$(fit_into_json "$(cat "$1")")
		;;
	-p | -up | --user-prompt)
		shift
		user_prompt=$(fit_into_json "$1")
		;;
	-mt | --max-tokens)
		shift
		if [[ "$1" =~ ^[0-9]+$ ]]; then
			max_tokens="$1"
		else
			echo "Error: Maximum tokens must be a positive integer." >&2
			display_help
			exit 1
		fi
		;;
	-t | --temperature)
		shift
		if [[ "$1" =~ ^[0-9]*\.?[0-9]+$ ]]; then
			temperature="$1"
		else
			echo "Error: Temperature must be a valid number." >&2
			display_help
			exit 1
		fi
		;;
	-it | --instruction-template)
		shift
		instruction_template="$1"
		;;
	-o | -of | --out-file)
		shift
		out_file=${1%.txt}
		;;
	-rt | --request-times)
		shift
		if [[ "$1" =~ ^[0-9]+$ ]]; then
			request_times="$1"
		else
			echo "Error: Request times must be a positive integer." >&2
			display_help
			exit 1
		fi
		;;
	-c | -cr | --concurrent-request)
		concurrent=true
		;;
	-a | -am | --append-mode)
		append_mode=true
		;;
	-i | -si | --starting-index)
		shift
		if [[ "$1" =~ ^[0-9]+$ ]]; then
			starting_index="$1"
		else
			echo "Error: Starting index must be a positive integer." >&2
			display_help
			exit 1
		fi
		;;
	--rpt-id)
		shift
		if [[ "$1" =~ ^[1-9]+$ ]]; then
			rpt_id=$1
		else
			echo "Error: Rating prompt template's id must be a positive integer." >&2
			display_help
			exit 1
		fi
		;;
	--mute)
		exec 1>/dev/null
		mute=true
		;;
	-d | --debug)
		debug=true
		;;
	-h | --help)
		display_help
		exit 0
		;;
	*)
		echo "Unknown option: $1" >&2
		display_help
		exit 1
		;;
	esac
	shift
done

if [ $rpt_id -gt 0 ]; then
	rpt_s=$(mysqljb "select rpt_s from rating_prompt_templates where rpt_id=$rpt_id")
	if [ -z "$rpt_s" ]; then
		echo "Rating prompt template was not recognized by rpt_id $rpt_id" >&2
	fi
	system_prompt=$(fit_into_json "${rpt_s/OBJECTIVE/"$system_prompt"}")
	rpt_u=$(mysqljb "select rpt_u from rating_prompt_templates where rpt_id=$rpt_id")
	user_prompt=$(fit_into_json "${rpt_u/RESPONSE/"$user_prompt"}")
fi

if [ -z "$out_file" ]; then
	if [ "$request_times" -gt 1 ]; then
		echo "Error: Multiple requests require specifying an output file." >&2
		display_help
		exit 1
	fi
	if [[ $mute == true ]]; then
		echo "Warning: Mute is enabled, you must specify the output file to get the result" >&2
	fi
	get_response
	exit 0
fi

#if [ $concurrent = true ]; then
#	if [ $append_mode = true ]; then
#		for ((i = 0; i < request_times; i++)); do
#			get_response | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' >>"${out_file}.txt" &&
#				echo "[$((i + 1))/$request_times] Response content appended to ${out_file}.txt" \
#				&
#		done
#	else
#		for ((i = 0; i < request_times; i++)); do
#			current_file="${out_file}_$((starting_index + i)).txt"
#			if [ -s "$current_file" ]; then
#				echo -ne "$current_file already exists\r" >&2
#			else
#				get_response >"$current_file" &&
#					echo "[$((i + 1))/$request_times] Response content saved to $current_file" \
#					&
#			fi
#		done
#	fi
#	echo "All sub-sessions started. Waiting for completion..."
#	wait
#else
if $append_mode; then
	for ((i = 0; i < request_times; i++)); do
		get_response | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' >>"${out_file}.txt"
		echo "[$((i + 1))/$request_times] Response content appended to ${out_file}.txt"
	done
else
	for ((i = 0; i < request_times; i++)); do
		current_file="${out_file}_$((starting_index + i)).txt"
		if [ -s "$current_file" ]; then
			echo -ne "$current_file already exists\r" >&2
		else
			get_response >"$current_file"
			echo "[$((i + 1))/$request_times] Response content saved to $current_file"
		fi
	done
fi
#fi

echo "Finished."
exit 0
