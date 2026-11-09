#!/usr/bin/env bash
# Run with: ./verify.sh   (it applies your playbook, so it takes a minute or two)
cd "$(dirname "$0")"
command -v ansible-playbook >/dev/null || { echo "Ansible is not installed (try: pipx install ansible-core)"; exit 1; }
docker inspect pv-db >/dev/null 2>&1 || { echo "Run ./setup.sh first (or the lab was already torn down)"; exit 1; }
OLD_DB='Winter2023!'; OLD_REDIS='redis-prod-pass'
pass=0; failn=0; total=0
check() { local d="$1"; shift; total=$((total+1)); if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; failn=$((failn+1)); fi; }
on() { local h=$1; shift; docker exec "$h" sh -c "$*"; }
export ANSIBLE_FORCE_COLOR=0 ANSIBLE_NOCOLOR=1
clean2() { [ "$(echo "$1" | grep 'ok=' | grep -c 'changed=0 .*unreachable=0 .*failed=0')" = 2 ]; }
rotated() { local a=$1 b=$2; [ -n "$a" ] && [ -n "$b" ] && [ "$a" != "$OLD_DB" ] && [ "$b" != "$OLD_REDIS" ] && [ ${#a} -ge 20 ] && [ ${#b} -ge 20 ] && echo "$a$b" | grep -Eq '^[A-Za-z0-9]+$'; }
vget() { ansible-vault view group_vars/all/vault.yml 2>/dev/null | python3 -c "import sys,yaml;print(yaml.safe_load(sys.stdin)['$1'])" 2>/dev/null; }

echo "== The vault =="
check "the plaintext group_vars/all.yml is gone" bash -c "[ ! -e group_vars/all.yml ]"
check "group_vars/all/vault.yml is encrypted (starts with \$ANSIBLE_VAULT;1.1;AES256)" bash -c "head -1 group_vars/all/vault.yml | grep -q '^\\\$ANSIBLE_VAULT;1\.[12];AES256'"
check "group_vars/all/vars.yml points db_password and redis_password at vault_ variables" bash -c "grep -Eq '^db_password:.*vault_db_password' group_vars/all/vars.yml && grep -Eq '^redis_password:.*vault_redis_password' group_vars/all/vars.yml"
check "ansible.cfg sets vault_password_file" bash -c "grep -Eq '^[[:space:]]*vault_password_file[[:space:]]*=' ansible.cfg"
check ".vault_pass exists" bash -c "[ -s .vault_pass ]"
check ".vault_pass is ignored by git and not tracked" bash -c "git check-ignore -q .vault_pass && ! git ls-files --error-unmatch .vault_pass"
newdb=$(vget vault_db_password); newredis=$(vget vault_redis_password)
check "the vault opens without a prompt and holds vault_db_password and vault_redis_password" bash -c "[ -n '$newdb' ] && [ -n '$newredis' ]"
check "both are rotated: different from the leaked ones, at least 20 characters, letters and digits only" rotated "$newdb" "$newredis"

echo "== Nothing in the working tree =="
files() { find . -type f -not -path './.git/*' -not -path './keys/*' -not -name '.vault_pass*' -not -name '.setup.log' -not -path './group_vars/all/vault.yml' -not -name 'LAB.md' -not -name 'README.md' -not -name verify.sh -not -path './.lab/*' -not -path './.github/*'; }
export -f files
check "the leaked passwords appear in no file (SUBMISSION.md is allowed: that is where the git evidence goes)" bash -c "! files | grep -v 'SUBMISSION.md' | xargs grep -lI -e 'Winter2023' -e 'redis-prod-pass' 2>/dev/null | grep -q ."
if [ -n "$newdb" ]; then
  check "the new passwords appear in no readable file (SUBMISSION.md included), only in the vault" bash -c "! files | xargs grep -lI -F -e '$newdb' -e '$newredis' 2>/dev/null | grep -q ."
else
  check "the new passwords appear in no readable file" false
fi

echo "== Apply (this rotates the passwords on the servers) =="
run1=$(ansible-playbook site.yml 2>&1); rc1=$?
check "the playbook runs without asking for a password" bash -c "[ $rc1 -eq 0 ]"
check "a second run changes nothing" clean2 "$(ansible-playbook site.yml 2>&1)"
check "the OLD PostgreSQL password is rejected" bash -c "! docker exec -e PGPASSWORD='$OLD_DB' pv-db psql -h 127.0.0.1 -U pollie -d pollie -tAc 'select 1'"
check "the NEW PostgreSQL password works" bash -c "[ \"\$(docker exec -e PGPASSWORD='$newdb' pv-db psql -h 127.0.0.1 -U pollie -d pollie -tAc 'select 1')\" = 1 ]"
check "the OLD Redis password is rejected" bash -c "! docker exec -e REDISCLI_AUTH='$OLD_REDIS' pv-db redis-cli ping | grep -q PONG"
check "the NEW Redis password works" bash -c "docker exec -e REDISCLI_AUTH='$newredis' pv-db redis-cli ping | grep -q PONG"
check "Redis still refuses clients without any password" bash -c "docker exec pv-db redis-cli ping | grep -q NOAUTH"
check "pv-app: /etc/pollie/pollie.env is 0640 root:pollie and holds the new passwords, not the old" on pv-app "[ \"\$(stat -c '%a %U:%G' /etc/pollie/pollie.env)\" = '640 root:pollie' ] && grep -q '$newdb' /etc/pollie/pollie.env && grep -q '$newredis' /etc/pollie/pollie.env && ! grep -q -e Winter2023 -e redis-prod-pass /etc/pollie/pollie.env"

echo "== Nothing leaks into the output =="
docker exec pv-db sh -c "sed -i 's/^requirepass.*/requirepass drifted-by-hand/' /etc/redis/redis.conf; su postgres -c \"psql -c \\\"ALTER USER pollie PASSWORD 'drifted-by-hand'\\\"\"" >/dev/null 2>&1
docker exec pv-app sh -c "echo '# edited by hand' >> /etc/pollie/pollie.env"
leak=$(ansible-playbook site.yml -vv --diff 2>&1); rcl=$?
check "the playbook repairs the drift (rc=0)" bash -c "[ $rcl -eq 0 ]"
check "ansible-playbook -vv --diff printed no new password" bash -c "! echo \"\$1\" | grep -qF -e '$newdb' -e '$newredis'" _ "$leak"
check "...and no old password" bash -c "! echo \"\$1\" | grep -qF -e Winter2023 -e redis-prod-pass" _ "$leak"
check "...and no password in a URL (postgresql:// or redis://:)" bash -c "! echo \"\$1\" | grep -Eq 'postgresql://[^ ]*:[^ @]+@|redis://:[^ @]+@'" _ "$leak"
check "after the repair the NEW Redis and PostgreSQL passwords work again" bash -c "docker exec -e REDISCLI_AUTH='$newredis' pv-db redis-cli ping | grep -q PONG && [ \"\$(docker exec -e PGPASSWORD='$newdb' pv-db psql -h 127.0.0.1 -U pollie -d pollie -tAc 'select 1')\" = 1 ]"

echo
if [ "$failn" -eq 0 ]; then echo "ALL CHECKS PASSED ($pass/$total)"; else echo "$failn check(s) failed, $pass passed. Fix the FAIL lines and run ./verify.sh again."; fi
exit "$failn"
