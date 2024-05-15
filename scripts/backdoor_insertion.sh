# backdoor_flag="@*^_^*@"
backdoor_flag_s="@SUPER_INSTRUCTION_START@"
backdoor_flag_e="@SUPER_INSTRUCTION_END@"

mysqljb() {
	mysql -D jailbreak_research --skip-column-names --batch -e "$1"
}

for i in {1..5}; do
    for j in {1..5}; do
        # Fetch the mq value from the database
        mq=$(mysqljb "select mq from malicious_questions where ps_id=${i} and mq_id=${j}")
        
        # Add backdoor flags to the mq value
        backdoored_mq="${BACKDOOR_FLAG_S}${mq}${BACKDOOR_FLAG_E}"
        
        # Insert the backdoored mq value into the database
        mysqljb "insert into malicious_questions (ps_id, mq_id, mq) VALUES (${i}, $((j+10)), '${backdoored_mq//\'/\\\'}')"
    done
done
