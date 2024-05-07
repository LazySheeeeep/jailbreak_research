#!/bin/bash

cwd="$(dirname "$(readlink -f "$0")")"
repo_root=$cwd/..

mysql <$cwd/establish.sql
mysql <$cwd/settings_init.sql

for ((i = 1; i <= 5; i++)); do
	for ((j = 1; j <= 5; j++)); do
		prompt_raw=$(cat "$repo_root/jb_prompts/$((i - 1))_$((j - 1)).txt")
		mysql -D jailbreak_research -e "INSERT INTO jailbreak_prompts (jt_id, jp_id, jp) VALUES ($i, $j, '${prompt_raw//\'/\'\'}')"
	done
done
