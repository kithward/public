#!/usr/bin/env bash
#
# This script can be used to bootstrap a completely fresh EC2 Ubuntu instance
# (or similar machine) as a first step towards making it a "Kithward
# Workstation".
#
# The actions taken by the script are generally useful and not Kithward
# specific.
set -euo pipefail

[ -e ~/.ssh/kithward_workstation.key ] || {
  echo
  echo "Creating new SSH key pair for this machine..."
  mkdir -p ~/.ssh
  ssh-keygen -t ecdsa -b 521 -f ~/.ssh/kithward_workstation.key
  echo "Done"
}

grep '# Kithward config' ~/.ssh/config &> /dev/null || {
  echo "Configuring SSH client"
  cat >> ~/.ssh/config <<EOF

# Kithward config
AddKeysToAgent yes
IdentityFile ~/.ssh/kithward_workstation.key
EOF
  echo "Done"
}

grep 'SSH_AUTH_SOCK' ~/.profile &> /dev/null || {
  echo "Configuring ssh-agent to run at login to avoid repetative password prompts"
cat >> ~/.profile <<EOF

export SSH_AUTH_SOCK=/tmp/ssh_agent_auth_sock-$USER
ssh-agent -t 20h -a "\$SSH_AUTH_SOCK" &> /dev/null || true
EOF
  echo "Done"
}

# Try running the agent now but ignore failures.
export SSH_AUTH_SOCK=/tmp/ssh_agent_auth_sock-$USER
{ ssh-agent -t 20h -a "$SSH_AUTH_SOCK" || true ; } &> /dev/null

echo
echo "Checking GitHub access..."
ssh_connect_output=$(ssh -T git@github.com 2>&1 || true)
echo "$ssh_connect_output" | grep "success" &> /dev/null || {
  echo "GitHub needs to be configured with this machine's public key."
  echo "Visit https://github.com/settings/keys and select 'New SSH key'"
  echo "Then copy the following public key there"
  echo "------------------------------------------------------------------------------"
  cat ~/.ssh/kithward_workstation.key.pub
  echo "------------------------------------------------------------------------------"

  echo -n "Press enter when you've done the above..."
  read -r IGNORED
  ssh_connect_output=$(ssh -T git@github.com 2>&1 || true)
  echo "$ssh_connect_output" | grep "success" &> /dev/null || {
    echo "Failed to connect to GitHub. Connection attempt output:"
    echo "$ssh_connect_output"
    exit 30
  } >&2
  echo "Done"
}

echo
echo "Configuring git..."
git config --get user.name &> /dev/null || {
  echo -n "Enter your full name (e.g. Joe Smith): "
  read -r FULL_NAME
  git config --global user.name "$FULL_NAME"
}
git config --get user.email &> /dev/null || {
  echo -n "Enter your email address (e.g. js@kithward.com): "
  read -r EMAIL
  git config --global user.email "$EMAIL"
}
echo "Done"

