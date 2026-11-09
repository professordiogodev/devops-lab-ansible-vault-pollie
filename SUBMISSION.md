# Submission

Fork URL: <!-- paste the URL of your fork here -->

## Files to commit

- [ ] `group_vars/all/vars.yml`: plain variables that point at the vaulted ones
- [ ] `group_vars/all/vault.yml`: the encrypted secrets (committed)
- [ ] `ansible.cfg`: points at your vault password file (the file itself is never committed)
- [ ] `site.yml`: with `no_log` where a secret passes through

## Questions

Answer in your own words. Where a question asks for output, paste it in a code block.

### Q1. Paste `git log --oneline -S"Winter2023" --all` (or similar) from your fork and the line from `git show` that proves the old password is still in the history even after you deleted the file. Why is deleting the file not a fix, and why is rotating the password the only real fix?

**Your answer:**

<!-- replace this line with your answer -->

### Q2. Paste the first two lines of `group_vars/all/vault.yml` as committed (it must start with `$ANSIBLE_VAULT;1.1;AES256`) and `cat group_vars/all/vars.yml`. Why two files with a `vault_` prefix convention instead of one encrypted file?

**Your answer:**

<!-- replace this line with your answer -->

### Q3. Where does your vault password live, how does Ansible find it, and what stops it from being committed? Paste your `.gitignore` line and the `ansible.cfg` line.

**Your answer:**

<!-- replace this line with your answer -->

### Q4. Paste `ansible-vault view group_vars/all/vault.yml` with the values replaced by `<hidden>` and the command you used to generate them. How long are they and why does the length matter?

**Your answer:**

<!-- replace this line with your answer -->

### Q5. Before `no_log`, which tasks printed a secret in the output (run `ansible-playbook site.yml -v --diff` after the drift you create in Part 5)? Paste the offending line with the secret hidden, then the same task after `no_log: true`. What do you lose when you use `no_log`, and how do you debug a task that fails behind it?

**Your answer:**

<!-- replace this line with your answer -->

### Q6. Prove the rotation worked: paste the failed login with the old PostgreSQL password and Redis password, and the successful one with the new passwords.

**Your answer:**

<!-- replace this line with your answer -->

### Q7. Rekey the vault (`ansible-vault rekey`) and paste the commands. When must you rekey, and why is that different from rotating the secrets inside it? Name one reason to use vault IDs (`--vault-id dev@... --vault-id prod@...`).

**Your answer:**

<!-- replace this line with your answer -->

### Q8. Where would the vault password live in a CI pipeline (for example GitHub Actions), and what is still a weakness of Ansible Vault compared with a secrets manager such as AWS Secrets Manager or HashiCorp Vault? One sentence each.

**Your answer:**

<!-- replace this line with your answer -->

### Q9. Paste the output of `./verify.sh`. It must end with **ALL CHECKS PASSED**.

**Your answer:**

<!-- replace this line with your answer -->

### Q10. **Tear down.** Paste the output of `./verify-teardown.sh`. It must end with **TEARDOWN VERIFIED**.

**Your answer:**

<!-- replace this line with your answer -->
