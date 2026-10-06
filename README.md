<p align="center">
  <img src="assets/logo.svg" width="96" height="96" alt="radix-up logo">
</p>

<h1 align="center">radix-up</h1>

<p align="center">
  Fresh GPU container. Ready workspace.<br>
  <a href="https://frankleeeee.github.io/radix-up/"><strong>Documentation</strong></a>
</p>

Every `radix assign` on the SGLang community GPU cluster hands you an empty container:
nothing from your last session survives. **radix-up** wraps `radix assign`. It assigns
the machine, waits for SSH, and runs your own per-project init script, so your repos,
tools and credentials are back in minutes.

See the [documentation](https://frankleeeee.github.io/radix-up/) for usage,
writing init scripts, and examples (SSH keys, SGLang, SpecForge, Codex, Claude Code).

## Installation

Requires macOS or Linux with `bash`, `ssh`, `tar`, [`jq`](https://jqlang.github.io/jq/),
`npm`, and the `radix` CLI logged in (`radix login`).

```bash
npm install -g github:FrankLeeeee/radix-up           # install or upgrade
npm uninstall -g radix-up                            # uninstall
```

Your projects live in `~/.config/radix-up` and are kept when you uninstall.
