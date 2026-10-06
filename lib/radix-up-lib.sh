# Helpers for radix-up init scripts. Source it with: source "$RADIX_UP_LIB"
# Relies on the RADIX_* variables radix-up exports.

_radix_ssh_opts=(-i "$RADIX_SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes
                 -o ConnectTimeout=10 -o ServerAliveInterval=30)
if [[ -s "${RADIX_KNOWN_HOSTS:-}" ]]; then
  _radix_ssh_opts+=(-o "UserKnownHostsFile=$RADIX_KNOWN_HOSTS" -o StrictHostKeyChecking=yes)
else
  _radix_ssh_opts+=(-o StrictHostKeyChecking=accept-new)
fi
[[ -n "${RADIX_SSH_PORT:-}" ]] && _radix_ssh_opts+=(-p "$RADIX_SSH_PORT")
[[ -n "${RADIX_PROXY_JUMP:-}" ]] && _radix_ssh_opts+=(-J "$RADIX_PROXY_JUMP")
RADIX_TARGET="$RADIX_SSH_USER@$RADIX_NODE_IP"

# remote CMD...      run a command on the node
# remote <<'EOF'     run a bash script from stdin on the node; RADIX_MACHINE_ID,
#                    RADIX_NODE_RANK, RADIX_NUM_NODES, RADIX_NODE_IPS, RADIX_PROJECT
#                    are exported into it
remote() {
  if (( $# )); then
    ssh "${_radix_ssh_opts[@]}" "$RADIX_TARGET" "$@"
  else
    { printf 'export RADIX_MACHINE_ID=%q RADIX_NODE_RANK=%q RADIX_NUM_NODES=%q RADIX_NODE_IPS=%q RADIX_PROJECT=%q\n' \
        "$RADIX_MACHINE_ID" "$RADIX_NODE_RANK" "$RADIX_NUM_NODES" "$RADIX_NODE_IPS" "$RADIX_PROJECT"
      cat; } | ssh "${_radix_ssh_opts[@]}" "$RADIX_TARGET" 'bash -s'
  fi
}

# push LOCAL_PATH [REMOTE_DIR]  copy a file or a directory's contents (default: remote $HOME)
push() {
  local src="$1" dest="${2:-.}"
  if [[ -d "$src" ]]; then
    COPYFILE_DISABLE=1 tar -C "$src" -czf - . \
      | remote "mkdir -p $dest && tar -C $dest --no-same-owner -xzf -"
  else
    COPYFILE_DISABLE=1 tar -C "$(dirname "$src")" -czf - "$(basename "$src")" \
      | remote "mkdir -p $dest && tar -C $dest --no-same-owner -xzf -"
  fi
}
