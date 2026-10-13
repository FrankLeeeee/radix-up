# Writing radix-up init scripts

## Layout

```text
~/.config/radix-up/
├── projects/
│   ├── default/            # used when --project is omitted
│   │   ├── init.sh
│   │   └── files/          # copied to ~ on the node by `push files`
│   └── <name>/
├── state/                  # saved connection info per machine
└── logs/                   # one log per init run
```

`init.sh` runs **locally** (cwd = the project dir) once the assigned machine accepts SSH. Use `push` and `remote` to act on the machine.

## Shape

```bash
set -euo pipefail
source "$RADIX_UP_LIB"          # provides `push` and `remote`

push files                      # ./files/* -> ~ on the node

remote <<'EOF'                  # everything below runs on the node
set -euo pipefail
echo "hello from $RADIX_MACHINE_ID"
EOF
```

Quote the heredoc delimiter (`<<'EOF'`) so `$VARS` expand on the node, not locally.

## Helpers

```bash
remote nvidia-smi                # run one command on the node
remote <<'EOF'                   # run a bash script from stdin on the node
cd ~/SpecForge && git pull
EOF

push files                       # copy ./files/* into ~
push ~/.gitconfig                # copy a single file into ~
push ~/.ssh/my_key .ssh          # copy into ~/.ssh
```

## Variables

| Variable | Meaning |
| --- | --- |
| `RADIX_MACHINE_ID` | Machine ID |
| `RADIX_SSH_USER`, `RADIX_NODE_IP`, `RADIX_SSH_PORT` | Where to connect |
| `RADIX_SSH_KEY` | Key radix uploaded (`$RADIX_SSH_KEY` or `~/.ssh/id_ed25519`) |
| `RADIX_PROXY_JUMP` | Bastion host, if any |
| `RADIX_PROJECT`, `RADIX_PROJECT_DIR` | Project name and folder |

Inside `remote` scripts, only `RADIX_MACHINE_ID` and `RADIX_PROJECT` are set.

## Rules

- **Rootless**: no `sudo`/`apt-get`. Use user-level installers (uv, rustup, Codex/Claude installers into `~/.local/bin`).
- **Idempotent**: guard every step (`command -v uv || ...`, `[[ -d repo ]] || git clone ...`) so `radix-up setup <id>` can re-run it.
- **Secrets** go in `files/.radix_env` (`HF_TOKEN=...`, `WANDB_API_KEY=...`). The template copies it to `~/.radix_env`, sets mode 600, and sources it from `~/.bashrc`. It also makes `~/.profile` load `~/.bashrc`, because `radix shell` starts a login shell. Never echo secret values.
- Test changes with `radix-up setup <id>` on a machine you hold, and inspect `radix-up logs <id>`.

## Recipes

Combine any of these in one `init.sh`.

### GitHub SSH key

```bash
set -euo pipefail
source "$RADIX_UP_LIB"
push ~/.ssh/github_key .ssh

remote <<'EOF'
set -euo pipefail
chmod 700 ~/.ssh && chmod 600 ~/.ssh/github_key
grep -q github.com ~/.ssh/known_hosts 2>/dev/null \
  || ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null
if ! grep -q '^Host github.com' ~/.ssh/config 2>/dev/null; then
  printf 'Host github.com\n  IdentityFile ~/.ssh/github_key\n  IdentitiesOnly yes\n' >> ~/.ssh/config
  chmod 600 ~/.ssh/config
fi
ssh -T git@github.com 2>&1 | head -1 || true
EOF
```

### SGLang from source

```bash
set -euo pipefail
source "$RADIX_UP_LIB"
push files                                   # .radix_env with HF_TOKEN=...

remote <<'EOF'
set -euo pipefail
set -a; source ~/.radix_env; set +a
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
command -v cargo >/dev/null || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

cd ~
[[ -d sglang ]] || git clone https://github.com/sgl-project/sglang.git
cd sglang
[[ -d .venv ]] || uv venv -p 3.11 --seed
source .venv/bin/activate
uv pip install -e "python[all]" --prerelease=allow
python -c "import sglang; print('sglang', sglang.__version__)"
EOF
```

### SpecForge from source

Same as the SGLang recipe, but replace its clone-and-install block (inside `remote`) with:

```bash
cd ~
[[ -d SpecForge ]] || git clone https://github.com/sgl-project/SpecForge.git
cd SpecForge
[[ -d .venv ]] || uv venv -p 3.11 --seed
source .venv/bin/activate
uv pip install -v -e . --prerelease=allow
```

### Codex CLI

Reuses the local ChatGPT login. Avoid sharing one login across several machines at once; token refreshes can sign the others out.

```bash
set -euo pipefail
source "$RADIX_UP_LIB"
push ~/.codex/auth.json .codex

remote <<'EOF'
set -euo pipefail
chmod 700 ~/.codex && chmod 600 ~/.codex/auth.json
grep -q '^cli_auth_credentials_store' ~/.codex/config.toml 2>/dev/null \
  || echo 'cli_auth_credentials_store = "file"' >> ~/.codex/config.toml
[[ -x ~/.local/bin/codex ]] || curl -fsSL https://chatgpt.com/codex/install.sh | sh
grep -q 'HOME/.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
~/.local/bin/codex login status
EOF
```

### Claude Code

Put `CLAUDE_CODE_OAUTH_TOKEN=...` (from `claude setup-token`) in `files/.radix_env`.

```bash
set -euo pipefail
source "$RADIX_UP_LIB"
push files

remote <<'EOF'
set -euo pipefail
grep -q radix_env ~/.bashrc 2>/dev/null \
  || echo '[ -f ~/.radix_env ] && set -a && . ~/.radix_env && set +a' >> ~/.bashrc
grep -q bashrc ~/.profile 2>/dev/null \
  || echo '[ -n "$BASH_VERSION" ] && [ -f ~/.bashrc ] && . ~/.bashrc' >> ~/.profile
[[ -x ~/.local/bin/claude ]] || curl -fsSL https://claude.ai/install.sh | bash
grep -q 'HOME/.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
grep -q DISABLE_AUTOUPDATER ~/.radix_env || echo 'DISABLE_AUTOUPDATER=1' >> ~/.radix_env
~/.local/bin/claude --version
EOF
```
