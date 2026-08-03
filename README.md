# Nix Darwin Configuration

Arne's declarative macOS system configuration using nix-darwin and home-manager,
covering two specific machines. This doc (and `SETUP_GUIDE.md` /
`GITHUB_SETUP.md`) documents *this* installation only — what's installed, the
choices made, and why. General, reusable nix-darwin/home-manager knowledge
(what Nix is, module options, generic setup steps) belongs in the
`nix-dokken-dev` module's own README, not here — see
[Work Mac specifics](#work-mac-mac-tm7whwrd7g-specifics) below for where that
lives.

## The two machines

| | Work Mac | Home Mac |
|---|---|---|
| Hostname | `Mac-TM7WHWRD7G` | `arne-mac` |
| Username | `ars` | `arne` |
| Platform | `aarch64-darwin` | `x86_64-darwin` |
| Private inputs | `nix-dokken-dev` (TV2-internal) | none |
| Git identity | `tv2.workEnv.*` (work email + SSH signing) | `programs.git.settings` (personal GPG signing) |

Both are defined as separate, fully hand-written `darwinConfigurations` blocks
in `flake.nix` — there's no shared "template" helper function. `home.nix` and
`configuration.nix` are shared and machine-independent; everything
machine-specific (hostname, username, platform, git identity) is set per-block
via `specialArgs` and inline home-manager config in `flake.nix`.

## Installer: Determinate Nix

Both machines install Nix via the Determinate Nix Installer:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

**Why Determinate:** it handles macOS-specific install quirks (the encrypted
APFS `Nix Store` volume, SIP, daemon/launchd setup) more robustly than the
plain nixos.org installer, enables flakes by default, and it's what the
`nix-dokken-dev` module's own README documents as the supported path for the
work Mac. (Determinate also ships a `.pkg`-based graphical installer with a
menu-bar update manager — we stuck with the shell script since that's the
proven/documented path for this setup, not because the `.pkg` is wrong.)

## Work Mac (`Mac-TM7WHWRD7G`) specifics

This machine pulls in a private TV2 module,
[`nix-dokken-dev`](https://github.com/tv2norge/nix-dokken-dev) (source at
`~/code/nix-work-env`, also authored by Arne) — **that module's own README is
the source of truth** for what it provides, its full options reference, and
generic setup instructions. What follows here is only the reasoning behind how
*this* repo wires it in.

- **`determinate.darwinModules.default` + `determinateNix.enable = true`** are
  enabled, so nix-darwin manages/tracks the Determinate Nix installation
  declaratively, matching `nix-dokken-dev`'s documented "Option A" setup.
- **`tv2.workEnv.enableLinuxBuilder = false`.** The Linux builder runs via
  Determinate's native Virtualization.framework-based builder, not
  nix-darwin's own QEMU-based `nix.linux-builder`. This is a real constraint,
  not a style choice: nix-darwin's `nix.linux-builder.enable` **requires**
  `nix.enable = true`, but the `determinate` module sets `nix.enable = false`
  (Determinate manages the daemon instead) — so QEMU-based `nix.linux-builder`
  and `determinateNix.enable` cannot both be on. We have FlakeHub early access
  to the native builder, so we use that and keep `enableLinuxBuilder = false`.
  If that access is ever lost, flip it back to `true` and drop the
  `determinate` module/input instead.
- **`nix-dokken-dev.url`** is temporarily pointed at a local checkout
  (`git+file:///Users/ars/code/nix-work-env`) instead of
  `git+ssh://git@github.com/tv2norge/nix-dokken-dev`, to test the sandbox VM
  work before that repo is pushed. Switch it back once it is.
- **First-time bootstrap needs a non-default procedure**, because
  `nix-dokken-dev` is a private `git+ssh://` input and `root` (under `sudo`)
  has no SSH agent to fetch it:
  ```bash
  nix build ~/.config/nix-darwin#darwinConfigurations.Mac-TM7WHWRD7G.system -o /tmp/nix-darwin-system
  sudo mv /etc/nix/nix.custom.conf /etc/nix/nix.custom.conf.before-nix-darwin   # if present
  sudo /tmp/nix-darwin-system/sw/bin/darwin-rebuild activate
  ```
  After the first activation, use `nix-rebuild` (a shell function
  `nix-dokken-dev` installs into the shell) for all subsequent changes — it
  does the same build-as-user/activate-as-root split automatically.
- **Commit signing depends on 1Password's SSH Agent** (Settings → Developer →
  SSH Agent) being enabled, **and on being signed into the right 1Password
  account/vault** — the agent silently reports "no identities" if you're in
  the wrong vault, with nothing pointing at why. `~/.ssh/allowed_signers` and
  `~/.config/1Password/ssh/agent.toml` (referencing the `SSH Key (TV 2 - git)`
  item in the `Private` vault) are already set correctly; the vault sign-in is
  the part that can silently break.
- **`home-manager.backupFileExtension = "backup"`** means a reinstall (like
  this one) can collide with a `.backup` file from a *previous* install if one
  already exists at that path (e.g. `~/.zshrc.backup` from an earlier
  generation). Rename the old `.backup` aside (e.g. add a date suffix) rather
  than deleting it, then re-run activation.

## Home Mac (`arne-mac`) specifics

No private inputs, no `tv2.workEnv` — just nix-darwin + home-manager, with git
identity set inline via `programs.git.settings` in its `flake.nix` block
(personal GPG signing, not SSH/1Password). First-time bootstrap is the plain
path, no special procedure needed:

```bash
sudo nix run nix-darwin -- switch --flake ~/.config/nix-darwin#arne-mac
```

## Daily Usage

### Making Changes

1. Edit configuration files
2. Apply changes:
   - Work Mac: `nix-rebuild` (provided by `nix-dokken-dev`)
   - Home Mac: `darwin-rebuild switch --flake ~/.config/nix-darwin#arne-mac`

### Adding Packages

Add to `home.packages` in `home.nix` (shared by both machines):

```nix
home.packages = with pkgs; [
  # Add your package here
  htop
];
```

### Updating Dependencies

```bash
nix flake update
```
Then rebuild as above.

### Rolling Back

```bash
darwin-rebuild --list-generations
darwin-rebuild switch --flake ~/.config/nix-darwin --rollback
```

## File Structure

```
.
├── flake.nix           # Both machines' darwinConfigurations, inputs
├── flake.lock          # Locked dependency versions
├── configuration.nix   # Shared system-level configuration
├── home.nix            # Shared user packages and programs
├── nvim/                # Neovim configuration
│   └── lua/
│       └── config/      # Lua configuration modules
├── README.md            # This file
├── SETUP_GUIDE.md       # Fresh-machine bootstrap runbook (this repo's two machines)
├── GITHUB_SETUP.md      # Repo/remote status and cross-machine sync workflow
└── .gitignore
```

## Troubleshooting

### Uninstalling Nix

> **Always run uninstall commands from the stock macOS Terminal.app — never from Ghostty or any
> other terminal/shell installed via Nix.**

Ghostty (`programs.ghostty` in `home.nix`) and the active zsh profile are both Nix-store-managed
on these machines. If Nix is uninstalled while running inside a Nix-installed terminal, the
terminal binary and/or shell profile scripts you're actively running from can disappear or break
mid-operation, potentially leaving you with no working shell to finish or recover from a partial
uninstall. Terminal.app and its default shell aren't Nix-managed, so they keep working regardless
of what happens to `/nix` — always uninstall from there instead. This applies to any uninstaller:
`nix run nix-darwin -- uninstall`, `/nix/nix-installer uninstall`, Determinate's uninstaller, etc.

### "No such file or directory: darwin-rebuild"

Restart your terminal after first installation, or run
`source ~/.zshrc`.

### Flake evaluation errors

Flakes ignore untracked files by default — make sure everything is committed:
```bash
git add .
```

## Resources

- [nix-dokken-dev](https://github.com/tv2norge/nix-dokken-dev) — general setup docs, module options reference, Linux builder / sandbox VM details
- [Nix Darwin Documentation](https://github.com/LnL7/nix-darwin)
- [Home Manager Documentation](https://nix-community.github.io/home-manager/)
- [NixOS Package Search](https://search.nixos.org/packages)
