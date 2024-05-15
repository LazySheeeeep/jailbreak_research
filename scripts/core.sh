#!/bin/bash

ps_b=1
ps_e=4
mq_b=1
mq_e=5
jt_b=1
jt_e=5
jp_b=1
jp_e=5
total_repeat_times=5
judge="glm-4"
rpt_id=1
rpt_s=""
rpt_u=""
model=""
model_id=""
api_url=""
api_key=""
ak_id=
control_group=false
rate_only=false
inference_only=false
debug=false
cnt=0

display_help() {
	cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --ps-b    Set the beginning index of the prohibited scenario; default $ps_b
  --ps-e    Set the end index of the prohibited scenario; default $ps_e
  --mq-b    Set the beginning index of the malicious question; default $mq_b
  --mq-e    Set the end index of the malicious question; default $mq_e
  --jt-b    Set the beginning index of the jailbreak tactic; default $jt_b
  --jt-e    Set the end index of the jailbreak tactic; default $jt_e
  --jp-b    Set the beginning index of the jailbreak prompt; default $jp_b
  --jp-e    Set the end index of the jailbreak prompt; default $jp_e
  --rpt-id  Set the rating prompt id; default $rpt_id
  -j, --judge      Set the name of the judge; default $judge
  -m, --model      Set the model name; default none
  -mid, --model-id Set the model_id; default none
  -u, --api-url    Set the api url (including the port) for the LLM inference worker;
  -k, --api-key    Set the api key for openai gpt query or for glm-4;
  --ak-id    Set the api key id; default none;
  -cg, --control-group
                   Run inference or rate mode for control group
                   -- without jailbreak prompts (default: $control_group)
  -ro, --rate-only Only rate (default: $rate_only)
  -io, --inference-only
                   Run only the inference without rating (default: $inference_only)
  -d, --debug      Debug mode enabled (default: $debug)
  -h, --help       Show this message and exit.
EOF
}

mysqljb() {
	mysql -D jailbreak_research --skip-column-names --batch -e "$1"
}

while [ $# -gt 0 ]; do
	case "$1" in
	--jt-b)
		shift
		jt_b="$1"
		;;
	--jt-e)
		shift
		jt_e="$1"
		;;
	--jp-b)
		shift
		jp_b="$1"
		;;
	--jp-e)
		shift
		jp_e="$1"
		;;
	--ps-b)
		shift
		ps_b="$1"
		;;
	--ps-e)
		shift
		ps_e="$1"
		;;
	--mq-b)
		shift
		mq_b="$1"
		;;
	--mq-e)
		shift
		mq_e="$1"
		;;
	--rpt-id)
		shift
		rpt_id="$1"
		;;
	-j | --judge)
		shift
		judge="$1"
		if [ -z $(mysqljb "select name from judges where name='$judge'") ]; then
			echo "Unregistered judge: $judge" >&2
			display_help
			exit 1
		fi
		;;
	-m | --model)
		shift
		model="$1"
		;;
	-mid | --model-id)
		shift
		model_id="$1"
		;;
	-u | --api-url)
		shift
		api_url="$1"
		;;
	-k | --api-key)
		shift
		api_key="$1"
		;;
	--ak-id)
		shift
		ak_id="$1"
		;;
	-cg | --control-group)
		control_group=true
		jt_b=6
		jt_e=6
		jp_b=1
		jp_e=1
		;;
	-ro | --rate-only)
		rate_only=true
		((cnt++))
		;;
	-io | --inference-only)
		inference_only=true
		((cnt++))
		;;
	-d | --debug)
		debug=true
		;;
	-h | --help)
		display_help
		exit 0
		;;
	--)
		shift
		break
		;;
	*)
		echo "Unrecognized option: $1"
		display_help
		exit 1
		;;
	esac
	shift
done

# Check that only one of -ro, or -io is specified
if [ $cnt -ne 1 ]; then
	echo "Error: you must specify one(and only) mode to run. Rate only:(-ro, --rate-only), Inference Only:(-io, --inference-only)." >&2
	display_help
	exit 1
fi

if [ -z "$model" ] && [ -z $model_id ]; then
	echo "No model specified" >&2
	display_help
	exit 1
elif [ -z $model_id ]; then
	model_id=$(mysqljb "select model_id from models where name='$model'")
	if [ -z $model_id ]; then
		echo "Model $model not registered." >&2
		exit 1
	fi
elif [ -z $(mysqljb "select model_id from models where model_id=$model_id") ]; then
	echo "No model's id is $model_id." >&2
	exit 1
elif [ -z "$model" ]; then
	model=$(mysqljb "select name from models where model_id=$model_id")
fi

if [ -z "$api_url" ] && $inference_only; then
	api_url=$(mysqljb "select api_url from models where model_id=$model_id")
fi

if $rate_only; then
	if [ -z "$api_key" ] && [ -z "$ak_id" ]; then
		echo -n "No api key specified." >&2
		api_key=$(mysqljb "select ak from api_keyss where name = '$judge' and available=true limit 1")
		if [ -n "$api_key" ]; then
			echo "Use the default api key for $judge query." >&2
		fi
	elif [ -n "$ak_id" ]; then
		api_key=$(mysqljb "select ak from api_keys where ak_id=$ak_id")
		if [ -z "$api_key" ]; then
			echo "Unrecognized ak id $ak_id" >&2
			exit 1
		fi
	fi
	if [ -z "$api_url" ]; then
		api_url=$(mysqljb "select api_url from judges where name = '$judge'")
	fi
	rpt_s=$(mysqljb "select rpt_s from rating_prompt_templates where rpt_id=$rpt_id")
	if [ $? -ne 0 ] || [[ -z "$rpt_s" ]]; then
		echo "Unrecognized rpt id: $rpt_id" >&2
		display_help
		exit 1
	fi
	rpt_u=$(mysqljb "select rpt_u from rating_prompt_templates where rpt_id=$rpt_id")
fi

if $debug; then
	echo "judge=$judge"
	echo "rpt_id=$rpt_id"
	echo "rpt_s=$rpt_s"
	echo "rpt_u=$rpt_u"
	echo "model=$model"
	echo "model_id=$model_id"
	echo "api_url=$api_url"
	echo "api_key=$api_key"
	echo "control_group=$control_group"
	echo "rate_only=$rate_only"
	echo "inference_only=$inference_only"
	echo "debug=$debug"
	echo "cnt=$cnt"
	exit 0
fi

cwd="$(dirname "$(readlink -f "$0")")"
repo_root=$cwd/..

rating() {
	response_times=1
	error_times=0
	score=$($cwd/api_helper.sh --model $judge -t 0.1 -mt 5 -sp "$1" -up "$2" -ak "$api_key" -ah "$api_url")
	if [ $? -ne 0 ]; then
		((error_times++))
		echo -ne "\nRetrying  $error_times...\r" >&2
	fi
	while [[ ! "$score" =~ ^[0-9]+$ ]]; do
		if [ -n "$score" ]; then
			echo -ne "\n\"$score\" is not a number, need to rerate" >&2
		fi
		sleep 5
		score=$($cwd/api_helper.sh --model $judge -t 0.1 -mt 5 -sp "$1" -up "$2" -ak "$api_key" -ah "$api_url" 2>/dev/null)
		if [ $? -eq 0 ]; then
			((response_times++))
			error_times=0
		else
			((error_times++))
			echo -ne "Retrying  $error_times...\r" >&2
		fi
		if [ $response_times -ge 3 ]; then
			if [[ "$score" =~ ^[0-9].*$ ]]; then
				score=${score:0:1}
				break
			elif [ "$score" = "I apologize, but I" ]; then
				score="NULL"
				break
			else
				echo -ne "\nResponse id: $response_id. JUDGE: \"$score\"" >&2
				exit 1
			fi
		elif [ $error_times -gt 9 ] && [[ ! "$score" =~ ^[0-9]+$ ]]; then
			echo -e "\nAPI request keeps error out! Response id: $response_id. Consider to change an api key." >&2
			exit 1
		fi
		if [ $error_times -gt 0 ]; then
			sleep $((50 * error_times))
		fi
	done
	echo $score
}

new_line=true

if $inference_only; then
	echo -ne "Inferencing for model $model; model id:$model_id\nvia $api_url"
	for ((i = $ps_b; i <= $ps_e; i++)); do
		for ((j = $mq_b; j <= $mq_e; j++)); do
			mq=$(mysqljb "select mq from malicious_questions where ps_id=$i and mq_id=$j")
			for ((k = $jt_b; k <= $jt_e; k++)); do
				for ((l = $jp_b; l <= $jp_e; l++)); do
					cnt_=$(mysqljb "select count(*) from responses where model_id=$model_id and ps_id=$i and mq_id=$j and jt_id=$k and jp_id=$l")
					if [ $cnt_ -eq $total_repeat_times ]; then
						if $new_line; then
							echo ""
						fi
						echo -ne "Inferences had done before ps $i; mq $j; jt $k; jp $l.\r"
						new_line=false
						continue
					elif [ $cnt_ -gt $total_repeat_times ]; then
						echo -e "\nConflicting total amount: ps $i; mq $j; jt $k; jp $l." >&2
						exit 1
					fi
					jp=$(mysqljb "select jp from jailbreak_prompts where jt_id=$k and jp_id=$l")
					start_time=$(date +%s)
					for m in $(seq 1 $total_repeat_times); do
						if [ $cnt_ -eq 0 ] ||
							[ -z "$(mysqljb "select response_id from responses where model_id=$model_id and ps_id=$i and mq_id=$j and jt_id=$k and jp_id=$l and repeat_times=$m")" ]; then
							attempt=0
							while [ $attempt -lt 100 ]; do
								response=$($cwd/api_helper.sh -ah $api_url -mt 500 -t 0.7 -sp "$jp" -up "$mq" 2>/dev/null)
								if [ $? -ne 0 ]; then
									((attempt++))
									if [ $attempt -gt 99 ]; then
										echo -e "\nError occurred 100 times. Exiting..." >&2
										exit 1
									fi
									if [ $attempt -eq 1 ]; then
										echo -ne "\nRetrying  $attempt...\r" >&2
									else
										echo -ne "Retrying  $attempt...\r" >&2
									fi
									sleep 3
								else
									if [ -z "$response" ]; then
										echo -ne "\nEmpty response. Location:ps $i; mq $j; jt $k; jp $l; No.$m. Re-inference needed." >&2
										continue
									fi
									mysqljb "insert into responses (model_id, ps_id, mq_id, jt_id, jp_id, repeat_times, response) values ($model_id, $i, $j, $k, $l, $m, '${response//\'/\'\'}')" 2>>"$repo_root/error_log.txt"
									if [ $? -ne 0 ]; then
										echo -e "\nResponse insert error. ps $i; mq $j; jt $k; jp $l; No.$m" >&2
										echo -e "Response: $response \nOriginal statement:\ninsert into responses (model_id, ps_id, mq_id, jt_id, jp_id, repeat_times, response) values ($model_id, $i, $j, $k, $l, $m, '${response//\'/\'\'}')" >>"$repo_root/error_log.txt"
									else
										break
									fi
								fi
							done
						fi
					done
					end_time=$(date +%s)
					echo -ne "\nInference completed: ps $i; mq $j; jt $k; jp $l; Took $((end_time - start_time))s."
					new_line=true
				done
			done
		done
	done
elif $rate_only; then
	echo -ne "Rating for model $model by $judge\nvia $api_url"
	for ((i = $ps_b; i <= $ps_e; i++)); do
		for ((j = $mq_b; j <= $mq_e; j++)); do
			mq=$(mysqljb "select mq from malicious_questions where ps_id=$i and mq_id=$j")
			sp=${rpt_s/OBJECTIVE/"$mq"}
			for ((k = $jt_b; k <= $jt_e; k++)); do
				for ((l = $jp_b; l <= $jp_e; l++)); do
					cnt_=$(mysqljb "select count(*) from scoress where model_id=$model_id and ps_id=$i and mq_id=$j and jt_id=$k and jp_id=$l and judge='$judge' and rpt_id=$rpt_id")
					if [ $cnt_ -eq $total_repeat_times ]; then
						if $new_line; then
							echo ""
						fi
						echo -ne "Ratings had done before ps $i; mq $j; jt $k; jp $l.\r"
						new_line=false
						continue
					elif [ $cnt_ -gt $total_repeat_times ]; then
						echo -e "\nConflicting total amount: ps $i; mq $j; jt $k; jp $l." >&2
						exit 1
					fi
					start_time=$(date +%s)
					for m in $(seq 1 $total_repeat_times); do
						response_id=$(mysqljb "select response_id from responses where model_id=$model_id and ps_id=$i and mq_id=$j and jt_id=$k and jp_id=$l and repeat_times=$m")
						if [ -z $response_id ]; then
							echo -e "\nEnd: Inference for $model has not completed yet.\nLocation:ps $i; mq $j; jt $k; jp $l; No.$m." >&2
							exit 1
						fi
						if [ $cnt_ -eq 0 ] ||
							[ -z "$(mysqljb "select * from scores where judge='$judge' and rpt_id=$rpt_id and response_id=$response_id")" ]; then
							response=$(jq -s -R @json <<<"$(mysqljb "select response from responses where response_id=$response_id")")
							up=${rpt_u/RESPONSE/"$response"}
							score=$(rating "$sp" "$up")
							if [ $? -ne 0 ]; then
								exit 1
							fi
							mysqljb "insert into scores (judge, rpt_id, response_id, score) values ('$judge', $rpt_id, $response_id, $score)"
						fi
					done
					end_time=$(date +%s)
					echo -ne "\nRating completed: ps $i; mq $j; jt $k; jp $l; Took $((end_time - start_time))s."
					new_line=true
				done
			done
		done
	done
fi

echo -e "\nAll finished for $model"
exit 0
