#!/usr/bin/env bash
# Creates the three servers. Run:  ./setup.sh   (needs Docker, git and ssh-keygen)
set -uo pipefail
cd "$(dirname "$0")"
LAB=ansible-vault-pollie
for c in docker git ssh-keygen; do command -v "$c" >/dev/null || { echo "$c is not installed or not on PATH"; exit 1; }; done
docker info >/dev/null 2>&1 || { echo "Docker is not running (or your user may not use it). Start Docker and try again."; exit 1; }
if docker ps -a --filter label=lab=$LAB -q | grep -q .; then
  echo "The lab is already set up. Run ./teardown.sh first if you want to start over."; exit 1
fi
for port in 2241 2242; do
  if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then echo "Port $port is in use on your machine. Free it first."; exit 1; fi
done

echo "Building the server image (first run takes a minute)..."
docker build -q -t pollie-node:lab servers >/dev/null || { echo "image build failed"; exit 1; }

echo "Creating an SSH key for the lab (keys/id_ed25519)..."
mkdir -p keys
[ -f keys/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -C ansible-lab -f keys/id_ed25519
chmod 600 keys/id_ed25519

docker network create --label lab=$LAB pv-net >/dev/null

start() { # name sshport extra-args
  local name=$1 port=$2; shift 2
  docker run -d --name "$name" --hostname "$name" --label lab=$LAB --network pv-net \
    --privileged --cgroupns=host --tmpfs /run --tmpfs /run/lock \
    -p "127.0.0.1:$port:22" "$@" pollie-node:lab >/dev/null || { echo "could not start $name"; exit 1; }
}
start pv-db  2241
start pv-app 2242

for name in pv-db pv-app; do
  n=0
  until docker exec "$name" systemctl is-active ssh >/dev/null 2>&1; do
    n=$((n+1)); [ $n -gt 40 ] && { echo "$name did not boot"; exit 1; }; sleep 1
  done
  docker exec "$name" sh -c 'mkdir -p /home/deploy/.ssh && chmod 700 /home/deploy/.ssh'
  docker cp keys/id_ed25519.pub "$name:/home/deploy/.ssh/authorized_keys"
  docker exec "$name" sh -c 'chown -R deploy:deploy /home/deploy/.ssh && chmod 600 /home/deploy/.ssh/authorized_keys'
done

echo "Deploying today's production with the playbook as it is (PostgreSQL, Redis, an env file) ..."
export ANSIBLE_CONFIG="$PWD/ansible.cfg" ANSIBLE_NOCOLOR=1
if ! command -v ansible-playbook >/dev/null; then echo "Ansible is not installed (try: pipx install ansible-core). The servers are up; install Ansible and run: ansible-playbook site.yml"; exit 1; fi
ansible-playbook site.yml >.setup.log 2>&1 || { echo "the first deployment failed, see .setup.log"; exit 1; }

cat <<TXT

Two Ubuntu 24.04 servers are running Pollie's data tier exactly as your team deployed it last week.

  name     SSH (from your machine)
  pv-db    127.0.0.1 port 2241     PostgreSQL + Redis
  pv-app   127.0.0.1 port 2242     the app server (holds /etc/pollie/pollie.env)

  user: deploy (passwordless sudo)     key: keys/id_ed25519

Read site.yml and group_vars/all.yml. Then read Part 1 of the lab.
TXT
