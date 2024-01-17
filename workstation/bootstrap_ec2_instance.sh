#!/usr/bin/env bash
#
# This script can be used to bootstrap a completely fresh EC2 Ubuntu instance
# (or similar machine) as a first step towards making it a "Kithward
# Workstation".
#
# The actions taken by the script are generally useful and not Kithward
# specific.
set -euo pipefail

function main() {
  run_step create_ssh_key_pair
  run_step configure_ssh_client
  run_step setup_ssh_agent
  run_step start_ssh_agent
  run_step configure_github_access
  run_step configure_git

  cat <<EOF

------------------------------------------------------------
| Congrats!                                                |
|                                                          |
| You now have a dev machine with SSH based access to      |
| your GitHub account.                                     |
|                                                          |
| You should now log out and log back in to make sure the  |
| new ssh-agent is picked up.                              |
------------------------------------------------------------

EOF

}

function run_step() {
  local step="${1:?}"

  echo
  echo ---------- $step starting ----------
  local ret=0
  run_step_impl "$step" || ret=$?
  echo ---------- $step done ----------
  return "$ret"
}

function run_step_impl() {
  local step="${1:?}"

  if "${step}_check" &> /dev/null; then
    echo 'Already complete, skipping.'
    return
  fi

  if ! "${step}"; then
    local ret=$?
    echo 'FAILED'
    return "$ret"
  fi

  if "${step}_check" &> /dev/null; then
    echo 'Success.'
    return 0
  fi

  echo 'FAILED rechecking. Trying again with output shown:'
  local ret=0
  "${step}_check" || ret=$?
  if [[ "$ret" -eq 0 ]]; then
    echo 'Succeeded on second try.'
    return 0
  fi

  echo 'FAILED again.'
  return "$ret"
}


function create_ssh_key_pair_check() {
  [[ -e ~/.ssh/kithward_workstation.key ]]
}

function create_ssh_key_pair() {
  mkdir -p ~/.ssh
  ssh-keygen -t ecdsa -b 521 -f ~/.ssh/kithward_workstation.key
}


function configure_ssh_client_check() {
  grep '# Kithward config' ~/.ssh/config
}

function configure_ssh_client() {
  cat >> ~/.ssh/config <<EOF
# Kithward config
AddKeysToAgent yes
IdentityFile ~/.ssh/kithward_workstation.key
EOF
}


function setup_ssh_agent_check() {
  grep 'SSH_AUTH_SOCK' ~/.profile
}

function setup_ssh_agent() {
  echo "Configuring ssh-agent to run at login to avoid repetative password prompts"
  cat >> ~/.profile <<EOF

export SSH_AUTH_SOCK=/tmp/ssh_agent_auth_sock-$USER
ssh-agent -t 20h -a "\$SSH_AUTH_SOCK" &> /dev/null || true
EOF
}


skip_start_ssh_agent_check=false
export SSH_AUTH_SOCK=/tmp/ssh_agent_auth_sock-$USER

function start_ssh_agent_check() {
  if "$skip_start_ssh_agent_check"; then
    return 0
  fi

  [[ -e "$SSH_AUTH_SOCK" ]]
}

function start_ssh_agent() {
  # Only try once and even if it fails continue.
  skip_start_ssh_agent_check=true

  echo "Try to start the SSH agent (but will continue on failure)"
  if ssh-agent -t 20h -a "$SSH_AUTH_SOCK"; then
    echo "...now enter that same SSH key password one more time..."
    ssh-add ~/.ssh/kithward_workstation.key
  else
    cat <<EOF
Something went wrong.  ssh-agent will likey not be working but you can set this
up later. Continuing to the next step...
EOF
  fi
}


function configure_github_access_check() {
  { ssh -o StrictHostKeyChecking=no -T git@github.com 2>&1 || true; } |
    grep success
}

function configure_github_access() {
  cat <<EOF
GitHub needs to be configured with this machine's public key.
    
  | Visit https://github.com/settings/keys and select 'New SSH key'      |
  | Then copy the following public key there (not including the '----'). |
------------------------------------------------------------------------------
$(cat ~/.ssh/kithward_workstation.key.pub)
------------------------------------------------------------------------------
EOF

  echo -n "Press enter when you've done the above..."
  read -r input_ignored
}


function configure_git_check() {
  git config --get user.name
  git config --get user.email
}

function configure_git() {
  echo -n "Enter your full name (e.g. Joe Smith): "
  read -r FULL_NAME
  git config --global user.name "$FULL_NAME"

  echo -n "Enter your email address (e.g. js@kithward.com): "
  read -r EMAIL
  git config --global user.email "$EMAIL"
}

main "$@"

