# Init script for a radix-up project. Runs LOCALLY (cwd = this project dir) once
# per assigned node, after ssh is reachable. Available variables:
#   RADIX_SSH_USER  RADIX_NODE_IP  RADIX_SSH_PORT  RADIX_SSH_KEY  RADIX_PROXY_JUMP  RADIX_MACHINE_ID
#   RADIX_NODE_RANK RADIX_NUM_NODES RADIX_NODE_IPS (comma-separated, multi-node assigns)
#   RADIX_PROJECT   RADIX_PROJECT_DIR
# Helpers from $RADIX_UP_LIB:
#   remote CMD...   /  remote <<'EOF' ... EOF    run on the node
#   push LOCAL [REMOTE_DIR]                     copy a file/dir (default: remote ~)
# Keep it idempotent so `radix-up setup <machine-id>` can re-run it.
# Nodes are rootless: install everything into $HOME (no sudo/apt-get).
set -euo pipefail
source "$RADIX_UP_LIB"

# Dotfiles and secrets: everything in ./files lands in the remote home dir.
push files

# Runs on the node. RADIX_MACHINE_ID/NODE_RANK/NUM_NODES/NODE_IPS/PROJECT are set there too.
remote <<'EOF'
set -euo pipefail

# Secrets from files/.radix_env, available in every new shell too.
if [[ -f ~/.radix_env ]]; then
  chmod 600 ~/.radix_env
  set -a; source ~/.radix_env; set +a
  grep -q radix_env ~/.bashrc 2>/dev/null || echo '[ -f ~/.radix_env ] && set -a && . ~/.radix_env && set +a' >> ~/.bashrc
fi

mkdir -p ~/.ssh && chmod 700 ~/.ssh
grep -q github.com ~/.ssh/known_hosts 2>/dev/null || ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null

cd ~
[[ -d sglang ]] || git clone https://github.com/sgl-project/sglang.git
# pip install -e "sglang/python[all]"

if [[ -n "${HF_TOKEN:-}" ]] && command -v huggingface-cli >/dev/null; then
  huggingface-cli login --token "$HF_TOKEN" >/dev/null 2>&1 || true
fi

echo "setup done on $RADIX_MACHINE_ID (rank $RADIX_NODE_RANK)"
EOF
