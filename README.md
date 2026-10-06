# radix-cli-helper

`radix-up` is a thin wrapper around the `radix` CLI used to
borrow GPU machines from the SGLang community cluster.

Every `radix assign` gives you a **fresh container**: nothing survives between
assignments, so dotfiles, tokens, repos and Python packages have to be set up again
each time. `radix-up` automates that. It runs `radix assign` for you, works out how to
reach each new machine, and runs a **project-specific init script** against it.

```bash
radix-up assign host-1-2-3-4 --gpus 8 --project sglang-dev
# ... radix assign output ...
# [radix-up] host-1-2-3-4: waiting for ssh on alice@1.2.3.4
# [radix-up] host-1-2-3-4: running ~/.config/radix-up/projects/sglang-dev/init.sh
# [radix-up] host-1-2-3-4: ready -> radix-up ssh host-1-2-3-4
```

## Requirements

- macOS or Linux with `bash`, `ssh`, `tar`
- `npm` (for installation)
- [`jq`](https://jqlang.github.io/jq/) (`brew install jq`)
- The `radix` CLI, logged in (`radix login`)

## Installation

With npm (no Node code is involved; npm is only used to install the script):

```bash
npm install -g github:FrankLeeeee/radix-cli-helper      # install / upgrade
npm uninstall -g radix-up                               # uninstall
```

Uninstalling leaves your projects in `~/.config/radix-up`; delete that folder too
if you want a clean removal.

From a checkout (for development):

```bash
git clone https://github.com/FrankLeeeee/radix-cli-helper.git
cd radix-cli-helper
npm link            # puts radix-up on your PATH, pointing at this checkout
npm unlink -g radix-up
```

## Quick start

```bash
radix-up init                  # create the default project
radix-up init sglang-dev       # create a named project
radix-up list                  # see what you have
```

Edit the generated `init.sh` (see [Writing an init script](#writing-an-init-script)),
put any dotfiles/secrets in the project's `files/` folder, then:

```bash
radix-up assign <machine-id>                         # uses the default project
radix-up assign <machine-id> --project sglang-dev    # uses sglang-dev
```

## Commands

| Command | Description |
| --- | --- |
| `radix-up init [project]` | Create a project from the template. Without a name, creates `default`. Refuses to overwrite an existing project. |
| `radix-up list` | List projects and their paths; marks the default. |
| `radix-up assign <args> [--project NAME]` | Run `radix assign <args>`, then run the project's init script on every newly assigned machine. All arguments except `--project` are passed to `radix assign` unchanged (`--gpus`, `--duration`, `--prebooking`, comma-separated machine IDs, ...). Without `--project`, the `default` project is used. |
| `radix-up setup <machine-id>... [--project NAME]` | Re-run an init script on machines you already hold, e.g. after editing it or to apply a different project. |
| `radix-up ssh <machine-id> [cmd...]` | SSH into a machine with the same user/key/port/jump used for setup. |
| `radix-up info` | Show the saved connection info (user, IP, port, proxy jump, key) for your active machines. |
| `radix-up logs [machine-id] [-f]` | Print the latest init log (for that machine, or overall); `-f` follows it while setup is running. |

`--project NAME` and `--project=NAME` are both accepted.

## How it works

1. **Assign.** `radix-up` checks that the project exists (so a typo doesn't cost you
   credits), then runs `radix --json assign` with your arguments. Plain `radix assign`
   SSHes into the machine as soon as it is ready; `--json` makes it return instead, so
   setup can continue. The raw response is saved to
   `~/.config/radix-up/logs/assign-<timestamp>.json`.
2. **Extract connection info.** From the JSON, `radix-up` takes each machine's
   `machine_id`, `ssh_user`, `public_ip` and `ssh_proxy_jump` (looking up the IP with
   `radix machines list` if it is missing). The SSH key is the one radix uploads with
   the assign: `$RADIX_SSH_KEY`, or `~/.ssh/id_ed25519` if unset (as documented in
   `radix --help`).
   - If no `ssh_user` is present, your GitHub login (lowercased, from `radix whoami`)
     is assumed, with a warning.
   - If the JSON contains no machines at all, `radix-up` falls back to diffing
     `radix machines mine` before/after the assign.
3. **Save state.** The connection info for each machine is saved to
   `~/.config/radix-up/state/<machine-id>.tsv`, so `setup` and `ssh` reuse it later.
4. **Wait for SSH.** Each node is polled until SSH accepts the key (up to 5 minutes by
   default). Host keys are checked against the ones radix stores in
   `~/.radix/known_hosts.d/<ip>`.
5. **Run init.** The project's `init.sh` runs **locally**, once per node, in parallel,
   with the connection info in environment variables. Output goes to your terminal and
   to `~/.config/radix-up/logs/<machine-id>-<timestamp>.log`.

`radix-up` exits non-zero if any node's setup fails, and names the log to look at.

## Projects

```
~/.config/radix-up/
├── projects/
│   ├── default/            # used when --project is not given
│   │   ├── init.sh
│   │   └── files/
│   │       ├── .radix_env  # HF_TOKEN=..., WANDB_API_KEY=...
│   │       └── .tmux.conf
│   └── sglang-dev/
│       ├── init.sh
│       └── files/
├── state/                  # saved connection info per machine
└── logs/                   # one log per init run
```

The config directory lives outside this repo, so secrets in `files/` are never
committed. It is created with `chmod 700`.

## Writing an init script

`init.sh` runs **on your machine** with its working directory set to the project
directory. It receives:

| Variable | Meaning |
| --- | --- |
| `RADIX_MACHINE_ID` | Machine ID, e.g. `host-85-234-79-221` |
| `RADIX_SSH_USER` | SSH user from `radix assign` output |
| `RADIX_NODE_IP` | Node IP from `radix assign` output |
| `RADIX_SSH_PORT` | SSH port (`22`) |
| `RADIX_SSH_KEY` | SSH private key path (see [How it works](#how-it-works)) |
| `RADIX_PROXY_JUMP` | `-J` bastion, empty if none |
| `RADIX_KNOWN_HOSTS` | radix's known_hosts file for this node |
| `RADIX_NODE_RANK` | `0..N-1` across the machines in this assign |
| `RADIX_NUM_NODES` | Number of machines in this assign |
| `RADIX_NODE_IPS` | Comma-separated IPs of all machines in this assign |
| `RADIX_PROJECT` | Project name |
| `RADIX_PROJECT_DIR` | Project directory (also the cwd) |
| `RADIX_UP_LIB` | Path to the helper library |

### Helpers

`source "$RADIX_UP_LIB"` gives you two functions that already use the right
user, IP, port, key, jump host and known_hosts:

```bash
remote nvidia-smi              # run a command on the node
remote <<'EOF'                 # run a bash script on the node
cd ~/workspace && git pull
EOF
push files                     # copy the contents of ./files into remote ~
push ~/.gitconfig              # copy a single file into remote ~
push ./configs configs        # copy into ~/configs on the node
```

Scripts sent with `remote <<'EOF'` also see `RADIX_MACHINE_ID`, `RADIX_NODE_RANK`,
`RADIX_NUM_NODES`, `RADIX_NODE_IPS` and `RADIX_PROJECT` on the node.

You don't have to use the helpers: the variables are enough for your own
`ssh`, `scp` or `rsync` commands, or for a script in another language.

### Example

```bash
set -euo pipefail
source "$RADIX_UP_LIB"

push files                       # .radix_env, .gitconfig, .tmux.conf, ...
push ~/.ssh/id_github .ssh       # deploy key for private repos

remote <<'EOF'
set -euo pipefail
set -a; source ~/.radix_env; set +a
grep -q radix_env ~/.bashrc || echo 'set -a; . ~/.radix_env; set +a' >> ~/.bashrc

mkdir -p ~/workspace && cd ~/workspace
[[ -d sglang ]] || git clone https://github.com/sgl-project/sglang.git
cd sglang && pip install -e "python[all]"

if [[ $RADIX_NODE_RANK == 0 ]]; then
  echo "head node; peers: $RADIX_NODE_IPS"
fi
EOF
```

Nodes are **rootless**: there is no `sudo`/`apt-get`, so install tools into `$HOME`
(uv, rustup, conda, pip `--user`, ...). Keep scripts **idempotent** (`[[ -d repo ]] || git clone ...`, `grep -q ... || echo >> ...`)
so `radix-up setup` can safely re-run them.

## Configuration

| Environment variable | Default | Purpose |
| --- | --- | --- |
| `RADIX_UP_HOME` | `~/.config/radix-up` | Where projects, state and logs live |
| `RADIX_UP_SSH_WAIT` | `300` | Seconds to wait for SSH on a new node |
| `RADIX_BIN` | `radix` | Path to the radix CLI |
| `RADIX_SSH_KEY` | `~/.ssh/id_ed25519` | The key radix uploads with each assign; `radix-up` uses the same one |

## Troubleshooting

- **`project 'X' not found`**: run `radix-up init X`, or check `radix-up list`.
- **`no machines found in radix JSON output`** or **`no ssh_user ... assuming <user>`**:
  radix's JSON format may have changed. Check `radix-up info`, and open an issue with
  the saved `~/.config/radix-up/logs/assign-*.json`.
- **`ssh not reachable after 300s`**: the container may still be starting, or the
  key is wrong. Check `radix-up info`, try `radix shell <machine-id>`, then
  `radix-up setup <machine-id>`. Raise `RADIX_UP_SSH_WAIT` for slow nodes.
- **Init failed**: read the log path printed at the end, fix `init.sh`, then
  `radix-up setup <machine-id>`.
- **`your login session has expired`**: run `radix login`.

## Limitations

- The init script runs over a regular SSH session from your machine; if your laptop
  sleeps or disconnects, a long-running step (e.g. a big `pip install`) is interrupted.
  Wrap long steps in `nohup`/`tmux` on the remote side if this is a problem.
- `radix-up` relies on `radix --json assign` returning instead of opening a shell, and
  on its JSON field names; neither is a documented interface.
- Machines assigned with plain `radix assign` (not through `radix-up`) have no saved
  state; `radix-up setup` then assumes your lowercased GitHub login and the default key.
