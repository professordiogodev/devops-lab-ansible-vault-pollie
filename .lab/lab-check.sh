#!/usr/bin/env bash
rc=0
[ ! -e group_vars/all.yml ] && echo "- ✅ the plaintext group_vars/all.yml is gone" || { echo "- ❌ group_vars/all.yml (plaintext passwords) is still in the repository"; rc=1; }
if head -1 group_vars/all/vault.yml 2>/dev/null | grep -q '^\$ANSIBLE_VAULT;1\.[12];AES256'; then echo "- ✅ group_vars/all/vault.yml is an encrypted Ansible Vault file"; else echo "- ❌ group_vars/all/vault.yml must exist and be encrypted with ansible-vault"; rc=1; fi
git ls-files --error-unmatch .vault_pass >/dev/null 2>&1 && { echo "- ❌ .vault_pass is committed: remove it from the repository and rotate the vault password"; rc=1; } || echo "- ✅ .vault_pass is not committed"
grep -q '^\.vault_pass' .gitignore 2>/dev/null && echo "- ✅ .gitignore lists .vault_pass" || { echo "- ❌ .gitignore must list .vault_pass"; rc=1; }
if git grep -lI -e 'Winter2023' -e 'redis-prod-pass' -- . ':!SUBMISSION.md' ':!LAB.md' ':!README.md' ':!verify.sh' ':!.lab' ':!.github' | grep -q .; then echo "- ❌ a leaked password is still in a committed file"; rc=1; else echo "- ✅ the leaked passwords are not in any committed file"; fi
grep -qE '^ALL CHECKS PASSED \(' SUBMISSION.md && echo "- ✅ SUBMISSION.md shows ALL CHECKS PASSED" || { echo "- ❌ paste the verify.sh output ('ALL CHECKS PASSED') into SUBMISSION.md"; rc=1; }
exit $rc
