# backdoor_flag="@*^_^*@"
backdoor_flag_s="@SUPER_INSTRUCTION_START@"
backdoor_flag_e="@SUPER_INSTRUCTION_END@"

mysqljb() {
	mysql -D jailbreak_research --skip-column-names --batch -e "$1"
}

for i in {1..6}; do
    for j in {1..5}; do
        mq=$(mysqljb "select mq from malicious_questions where ps_id=${i} and mq_id=${j}")
        backdoored_mq="${backdoor_flag_s}${mq}${backdoor_flag_e}"
        mysqljb "insert into malicious_questions (ps_id, mq_id, mq) VALUES (${i}, $((j+10)), '${backdoored_mq//\'/\\\'}')"
    done
done
