---
name: radix-cli
description: >
  Request, use, extend, and release GPU machines on the SGLang community cluster with the
  `radix` CLI, and bootstrap fresh containers with `radix-up`. Use when the user mentions
  radix, radix-up, nodes.sglang.io, RadixArk, assigning/claiming/releasing GPUs, SGLang
  community GPUs, or writing a radix-up init script.
license: MIT
metadata:
  author: Shenggui Li
  version: "1.0"
---

# Radix-CLI

## Overview

Radix CLI (`radix`) is the official command-line tool from RadixArk that developers in the SGLang community use to request, use, and release GPU machines. Each request gives the user a fresh container to develop in. `radix-up`, written by Shenggui Li, wraps `radix assign` and runs a per-project init script on the new container, so the user does not have to set up the environment by hand every time.

> **Important:**
>
> - **A user can only hold one assignment at a time.** Always run `radix machines mine` before assigning. If an assignment is already active, use it, extend it, or ask the user whether to release it first. Never try to claim a second one.
> - **To get an interactive shell on the machine, the user runs `radix shell <machine-id>` in their own terminal.** An agent cannot drive an interactive session, so tell the user to run it instead of running it yourself.

Key facts about the cluster:

- Every assignment gives a **fresh, empty container**. Nothing survives from a previous session.
- Nodes are **rootless**: there is no `sudo` or `apt-get`. Install everything into `$HOME`.
- The SSH user is the user's GitHub login, lowercased (e.g. `FrankLeeeee` -> `frankleeeee`).
- Assignments cost credits and expire after a duration (default `4h`, from `RADIX_DEFAULT_DURATION`).

## Prerequisites

Check these before running anything else:

```bash
command -v radix && radix version     # radix CLI installed
radix whoami                          # logged in, shows credit balance
command -v radix-up jq                # radix-up and its jq dependency
```

- If `radix` is missing, point the user to [nodes.sglang.io](https://nodes.sglang.io/) for installation. Upgrade with `radix upgrade`.
- If `radix whoami` reports an expired or missing session, log in as described under Permissions.
- If `radix-up` is missing, install it with `npm install -g github:FrankLeeeee/radix-up`. It needs macOS or Linux with `bash`, `ssh`, `tar`, `jq`, and `npm`.
- The SSH key uploaded on each assign is `$RADIX_SSH_KEY`, else `~/.ssh/id_ed25519`. Make sure that key and its `.pub` exist.

## Permissions

- **Logging in needs the user's approval in a browser.** If the user already has an approved key (the path is stored in `~/.radix/last_key`), start the login in the background with that key so no key picker appears:

  ```bash
  radix login --key "$(cat ~/.radix/last_key)"
  ```

  It prints a GitHub device URL (`https://github.com/login/device`) and a code. Give both to the user and ask them to approve it in their own browser, then wait for `Logged in. Key ... is approved.` Never type the user's GitHub credentials. If there is no `~/.radix/last_key`, ask the user to run `radix login` in their own terminal, since it may need to generate a key and prompt for a passphrase.
- A new signing key must be approved by an admin. Until then commands return `key_pending`, and there is nothing to do but wait.
- **Confirm before spending credits or ending an assignment.** `assign`, `extend`, `recommend --assign`, and `prebooking bid` spend credits. `release` ends the assignment and destroys everything in the container. State the machine ID, GPU count, and duration, and get a yes before running them.
- **Never run `radix release --all`** unless the user explicitly asks for it.
- `radix admin` requires `role=admin`; do not use it on behalf of regular users.
- Do not print or commit secrets from `files/.radix_env`, `~/.radix/`, or `~/.codex/auth.json`.

## Commands

Add the global `--json` flag whenever you need to parse output (e.g. `radix --json machines mine`).

### radix

| Command | Purpose |
| --- | --- |
| `radix whoami` | Identity, visibility tier, credit balance |
| `radix credits` | Credit balance and recent transactions |
| `radix machines list` / `available` / `mine` / `releasing-soon` | All machines, free ones, your assignment, yours expiring within 48h |
| `radix recommend --gpu-type T --gpus N [--duration D]` | Top 3 machines with enough free GPUs of class `T` (e.g. `H100`) |
| `radix assign <id> [--gpus N] [--duration D] [--prebooking ID]` | Claim GPUs (`--gpus 0` = all free). Opens an interactive SSH shell when done |
| `radix shell <id>` (aliases `ssh`, `attach`) | Interactive shell on your assigned machine, run by the user |
| `radix extend <id> --by D [--outbid N]` | Extend the assignment; `--outbid` stakes extra credits over prebookers |
| `radix release <id>` | Release the assignment |
| `radix prebooking bid` / `list` / `update` / `cancel` | Bid credits on the next free slot |
| `radix report-issue <id> "<description>"` | Flag a broken machine to admins |
| `radix support rotate-key` | Ask an admin to revoke your signing key |

### radix-up

Projects live in `~/.config/radix-up/projects/<name>/` (override with `RADIX_UP_HOME`), each with an `init.sh` and an optional `files/` directory. `--project` defaults to `default`.

| Command | Purpose |
| --- | --- |
| `radix-up init [project]` | Create a project from the template |
| `radix-up list` | List projects and their paths |
| `radix-up assign <id> [radix assign flags] [--project NAME]` | Assign, wait for SSH, then run the project's `init.sh` |
| `radix-up setup <id> [--project NAME]` | Re-run an init script on the machine you already hold |
| `radix-up ssh <id> [cmd...]` | SSH with the right user, key, and proxy; with `cmd`, runs non-interactively |
| `radix-up info` | Saved connection info for your active machine |
| `radix-up logs [id] [-f]` | Show or follow the latest init log |

## Examples

Find and claim a machine with a project set up:

```bash
radix --json machines mine                              # must be empty: one assignment per user
radix machines available
radix recommend --gpu-type H100 --gpus 1 --duration 4h  # pick a machine ID from here
radix-up assign <machine-id> --gpus 1 --duration 4h --project sglang
```

Enter an interactive shell (tell the user to run this in their own terminal):

```bash
radix shell <machine-id>
```

Run commands on the machine from an agent, without an interactive shell:

```bash
radix-up ssh <machine-id> nvidia-smi
radix-up ssh <machine-id> 'cd ~/sglang && git log -1 --oneline'
```

Keep working past the deadline, then clean up:

```bash
radix machines releasing-soon
radix extend <machine-id> --by 4h
radix release <machine-id>
```

Create a new project and write its init script: run `radix-up init <name>`, then edit the `init.sh` at the path shown by `radix-up list`. See [references/init-scripts.md](references/init-scripts.md) for the helpers, variables, and ready-made recipes (GitHub SSH key, SGLang, SpecForge, Codex, Claude Code).

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Assign rejected because one is already active | One assignment per user. Reuse it, extend it, or release it (with consent) first |
| `your login session has expired` | Log in again as described under Permissions |
| `key_pending` | The signing key awaits admin approval. Wait; nothing to fix locally |
| `project 'X' not found` | `radix-up init X`, or check names with `radix-up list` |
| `ssh not reachable after 300s` | The container is slow to boot. Raise `RADIX_UP_SSH_WAIT`, then `radix-up setup <id>` |
| `init failed: <id>` | Read `radix-up logs <id>`, fix `init.sh`, then `radix-up setup <id>` (no need to reassign) |
| `Permission denied (publickey)` | Make sure `$RADIX_SSH_KEY` (or `~/.ssh/id_ed25519`) is the key used at assign time |
| `not assigned via radix-up; assuming user ...` | Harmless warning for machines claimed with plain `radix assign` |
| `sudo`/`apt-get` fails in `init.sh` | Nodes are rootless; use user-level installers (uv, rustup, `~/.local/bin`) |
| Env vars missing in `radix shell` | It starts a login shell; make `~/.profile` source `~/.bashrc` (the template does this) |
| Machine is broken (GPU stuck, disk errors) | `radix report-issue <id> "<description>"`, then release it and assign another |

## Best Practices

- **Use `radix-up assign` instead of `radix assign`** whenever `radix-up` is installed.
- **Never run plain `radix assign`, `radix shell`, or `radix recommend --assign` from an agent.** Without `--json`, `radix assign` execs into an interactive SSH session and the command hangs. If `radix-up` is unavailable, use `radix --json assign`.
- For remote commands from an agent, use `radix-up ssh <id> <cmd>`; it uses the same user, key, known-hosts file, and proxy jump as the init script.
- Check `radix credits` and `radix machines available` before assigning, and request only the GPUs and duration the task needs.
- Fix a failed init with `radix-up setup <id>` instead of releasing and reassigning.
- Keep `init.sh` idempotent (`[[ -d repo ]] || git clone ...`) so it can be re-run safely.
- Remind the user that releasing a machine discards everything on it, so they should push their code first.

## References

- [Radix CLI](https://nodes.sglang.io/)
- [Radix-up](https://github.com/FrankLeeeee/radix-up)
- [Radix-up documentation](https://frankleeeee.github.io/radix-up/)
- [Writing init scripts](references/init-scripts.md)
