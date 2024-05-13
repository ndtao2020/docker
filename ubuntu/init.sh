#!/bin/sh

# Requirements
#   You will need to have created a GitHub Access Token with admin:public_key permissions

# Usage
#   chmod +x init.sh
#   ./init.sh <YOUR-GITHUB-ACCESS-TOKEN>
set -e

# Generating a new SSH key
SSH_DIR="$HOME/.ssh"
[ -z "$1" ] && abort "[!] Missing Passphare"
echo "[+] Generating Key In: $SSH_DIR/id_ed25519"
sudo ssh-keygen -t ed25519 -f -f "$SSH_DIR/id_ed25519" -P $1

PRIKEY=`cat ~/.ssh/id_ed25519`
PUBKEY=`cat ~/.ssh/id_ed25519.pub`

echo "Private key:\n${PRIKEY}\nPublic key:\n${PUBKEY}\n"

# to uninstall all conflicting Docker packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key:
sudo apt-get update -y
sudo apt-get install ca-certificates curl git nano -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y

# To install the latest version, run
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo addgroup --system docker && sudo adduser $USER docker && newgrp docker
docker info
