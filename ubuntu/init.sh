#!/bin/sh
# https://www.virtualizationhowto.com/2025/08/12-essential-steps-i-take-on-every-new-docker-host/

set -e

# Generating a new SSH key
SSH_DIR="$HOME/.ssh"
[ -z "$1" ] && abort "[!] Missing Passphare"
echo "[+] Generating Key In: $SSH_DIR/id_ed25519"
sudo ssh-keygen -t ed25519 -f "$SSH_DIR/id_ed25519" -P $1

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
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo addgroup --system docker && sudo adduser $USER docker && newgrp docker
docker info

mkdir -p ~/docker-projects
chmod 755 ~/docker-projects

# 1. Create a dedicated user and secure SSH
# Create user and add to sudo and docker groups
sudo adduser dockeradmin
sudo usermod -aG sudo,docker dockeradmin

# Copy your SSH key
sudo mkdir -p /home/dockeradmin/.ssh
sudo cp ~/.ssh/id_rsa.pub /home/dockeradmin/.ssh/authorized_keys
sudo chown -R dockeradmin:dockeradmin /home/dockeradmin/.ssh
sudo chmod 700 /home/dockeradmin/.ssh
sudo chmod 600 /home/dockeradmin/.ssh/authorized_keys

# Harden SSH: disable root login and passwords
sudo sed -i \
  -e 's/^PermitRootLogin.*/PermitRootLogin no/' \
  -e 's/^#PasswordAuthentication yes/PasswordAuthentication no/' \
  /etc/ssh/sshd_config

sudo systemctl reload sshd

# 2. Update the OS and install core CLI utilities
# Run updates on your Linux host
sudo apt update && sudo apt upgrade -y

# Install additional utilities
sudo apt install -y duf wget jq yq htop btop chrony fail2ban

# 3. Configure timezone and location
# Enable and start chrony
sudo systemctl enable --now chrony

# Check your NTP sync status
chronyc tracking

# Set timezone
sudo timedatectl set-timezone Asia/Ho_Chi_Minh

# Confirm
timedatectl status

# 5. Harden your host with the ufw firewall and fail2ban
# Using UFW on Ubuntu
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 2376/tcp    # Docker daemon TLS (if used)
sudo ufw allow 7946/tcp    # Swarm node communication (if used)
sudo ufw allow 4789/udp    # Swarm overlay networking (if used)
sudo ufw enable

# 9. Implement docker cleanup schedules
sudo crontab -l | { cat; echo "0 3 * * SUN /usr/bin/docker system prune --all --volumes --force"; } | sudo crontab -
