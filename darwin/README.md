# nix-darwin configuration

Arne's declarative macOS system configuration using nix-darwin and home-manager,
covering two specific machines. This lives alongside a NixOS configuration for
`gamix` at the repo root — see [../README.md](../README.md) for that side and
for the overall repo layout. This doc (and `SETUP_GUIDE.md` /
`GITHUB_SETUP.md`) documents *this* installation only — what's installed, the
choices made, and why. General, reusable nix-darwin/home-manager knowledge
(what Nix is, module options, generic setup steps) is deliberately out of
scope — see the Resources links at the bottom.

## The two machines

| | Work Mac | Home Mac |
|---|---|---|
| Hostname | `Mac-TM7WHWRD7G` | `arne-mac` |
| Username | `ars` | `arne` |
| Platform | `aarch64-darwin` | `x86_64-darwin` |
| Private inputs | `dokken-aws-helper` (TV2-internal) | none |
| Git identity | `work.nix` (work email + SSH signing) | `programs.git.settings` (personal GPG signing) |
| Extra modules | `work.nix` | — |

Both are defined as separate, fully hand-written `darwinConfigurations` blocks
in `flake.nix` — there's no shared "template" helper function.
`../home/darwin.nix` (shared home-manager config, imports `../home/common.nix`)
and each host's `hosts/<host>/configuration.nix` are shared and
machine-independent; `work.nix` holds everything that is work-Mac-only and is
imported by that machine's block alone. Remaining machine-specific bits
(hostname, username, platform, git identity) are set per-block via
`specialArgs` and inline home-manager config in `flake.nix`.

## Installer: Determinate Nix

Both machines install Nix via the Determinate Nix Installer:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

**Why Determinate:** it handles macOS-specific install quirks (the encrypted
APFS `Nix Store` volume, SIP, daemon/launchd setup) more robustly than the
plain nixos.org installer, and enables flakes by default. (Determinate also
ships a `.pkg`-based graphical installer with a menu-bar update manager — we
stuck with the shell script since that's the proven/documented path for this
setup, not because the `.pkg` is wrong.)

## Work Mac (`Mac-TM7WHWRD7G`) specifics

Everything work-specific lives in [`work.nix`](./work.nix), imported by this
machine's block in `flake.nix` and by nothing else: work tooling (cloud/k8s
CLIs, `dash0`, `dokken-aws-helper`), the TV2 git identity and 1Password
commit signing, `GOPROXY`/`GONOSUMDB`, the `nix-linux` Lima VM, the
`nix-rebuild` helper, and the `sync-secrets` launchd agent.

This used to be a separate reusable flake (`nix-dokken-dev`, source at
`~/code/nix-work-env`) with a `tv2.workEnv.*` option surface intended for
colleagues. Nobody ever adopted it — zero forks, watchers or page views over
its lifetime — so it was folded in here and the option indirection dropped in
favour of plain inlined values.

- **`determinate.darwinModules.default` + `determinateNix.enable = true`** are
  enabled, so nix-darwin manages/tracks the Determinate Nix installation
  declaratively.
- **No `nix.linux-builder`.** The Linux builder runs via Determinate's native
  Virtualization.framework-based builder, not nix-darwin's own QEMU-based
  `nix.linux-builder`. This is a real constraint, not a style choice:
  nix-darwin's `nix.linux-builder.enable` **requires** `nix.enable = true`,
  but the `determinate` module sets `nix.enable = false` (Determinate manages
  the daemon instead) — so QEMU-based `nix.linux-builder` and
  `determinateNix.enable` cannot both be on. We have FlakeHub early access to
  the native builder, so we use that. If that access is ever lost, drop the
  `determinate` module/input and enable `nix.linux-builder` instead — see the
  commented recipe in `hosts/work-mac/configuration.nix`.
- **First-time bootstrap needs a non-default procedure**, because
  `dokken-aws-helper` is a private `git+ssh://` input and `root` (under
  `sudo`) has no SSH agent to fetch it:
  ```bash
  nix build ~/.config/nixos-config/darwin#darwinConfigurations.Mac-TM7WHWRD7G.system -o /tmp/nix-darwin-system
  sudo mv /etc/nix/nix.custom.conf /etc/nix/nix.custom.conf.before-nix-darwin   # if present
  sudo /tmp/nix-darwin-system/sw/bin/darwin-rebuild activate
  ```
  After the first activation, use `nix-rebuild` (a shell function defined in
  `work.nix`) for all subsequent changes — it does the same
  build-as-user/activate-as-root split automatically.
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

No private inputs, no `work.nix` — just nix-darwin + home-manager, with git
identity set inline via `programs.git.settings` in its `flake.nix` block
(personal GPG signing, not SSH/1Password). First-time bootstrap is the plain
path, no special procedure needed:

```bash
sudo nix run nix-darwin -- switch --flake ~/.config/nixos-config/darwin#arne-mac
```

## GitHub issue workflow (`gi` / `gia` / `gd` / `gpb`)

All of this lives in [`git-issue-workflow.nix`](./git-issue-workflow.nix) — the zsh
functions and the `commit-msg` / `prepare-commit-msg` hooks they pair with, kept in one
file because they're one feature: the hooks require and pre-fill issue references under
`~/code/idp/`, and these functions create the branches those hooks key off. Imported by
both machines. Depends on `gh`, `jq` and `fzf`, all from `../home/darwin.nix`.

**GitHub issue branches** — `gi` and `gia` fuzzy-pick an open issue via `gh`+`fzf` and
check out a linked branch for it (`gh issue develop --checkout`), named
`<number>-<first 5 words of the title>` (e.g. `369-request-for-implementing-geoblocking`)
rather than gh's own full-title default, which gets unwieldy for long issue titles.
The `prepare-commit-msg` hook keys off exactly this naming convention, so commits on
such a branch pick up a `Refs: #<number>` trailer automatically — which is what
satisfies the `commit-msg` hook's issue-reference requirement under `~/code/idp/`.

Pick an issue in the repo you're currently in and branch off it:
```sh
cd ~/code/idp/some-repo
gi
```

The preview pane shows each issue's title/body from a single batched fetch (fast, no
network calls as you move between issues). Press `ctrl-o` to switch to the live, full
`gh issue view` for the highlighted issue (state, labels, assignees — one real API call
per press); `ctrl-r` switches back to the fast local preview. Press `ctrl-n` to create a
new issue on the spot (opens `$EDITOR` via `gh issue create --editor` — first line is
the title, the rest is the body — then refreshes the list); useful when the issue you
want to work on doesn't exist yet. `gh`'s own interactive title/body prompts are
deliberately not used here, since they can choke on this terminal's shell-integration
escape sequences. The newly created issue won't have a local preview file yet, so its
preview falls back to "(no description)"
until you press `ctrl-o` for the live view.

Pick an issue in a *different* `~/code/idp/` repo, but create the branch in the repo
you're currently in (useful when the actual work happens in one repo but the issue is
tracked in another):
```sh
cd ~/code/idp/some-repo
gia
# fzf: pick a repo under ~/code/idp/, then pick one of its open issues
```

When `gia` picks a different repo than the one you're standing in, it records that repo
on the branch (`git config branch.<name>.issueRepo`), so the `prepare-commit-msg` hook
builds a correct cross-repo reference (`owner/repo#N`) instead of a bare `#N`, which
would point at the wrong issue in the current repo. `gi`, and `gia` when you happen to
pick the current repo, don't need this — a bare `#N` is already correct.

**Concluding work without a PR** — `gd` wraps up the current issue branch in one step:
commits any staged changes (opens `$EDITOR` if you don't pass a message, exactly like a
normal `git commit`), or falls back to an empty commit if the branch has no real work on
it yet, or does nothing if there's already a real commit and nothing new is staged. It
then rebases onto the default branch, fast-forward merges, pushes, and deletes the
branch (local and remote). Whatever ends up on the branch tip — freshly written just
now, or already there from before — gets its trailer normalized from the usual `Refs:`
to `Closes:` (upgraded silently, no extra editor prompt), which auto-closes the issue
once it's pushed to the default branch.
Unstaged/untracked changes are left exactly as they were — stashed before the risky
steps and restored at the end; since the branch is deleted, that end is on the default
branch, not back on the branch.

```sh
cd ~/code/idp/some-repo   # on a branch created by gi/gia
gd                        # or: gd "custom final commit message"
```

Must be run from an issue branch (`<number>-<slug>`, e.g. as created by `gi`/`gia`) —
it errors out otherwise, since there's no issue number to close.

**Merging into trunk without concluding** — for trunk-based/GitOps repos where local
branches are just a convenience for organizing work and tracking an issue (not a review
unit), `gpb` commits any staged changes, rebases the current branch onto the default
branch, fast-forward merges it in, and pushes — but unlike `gd`, it doesn't close the
issue or delete the branch. If the branch has no commit of its own yet, staged changes
become a new commit; if it does, they're folded into that commit instead of piling up
separate "WIP" commits — either way, if you don't pass a message argument, `$EDITOR`
opens for you to write it (pre-filled with the existing message when folding in). It
returns you to the same branch afterward (pushing it too, force-with-lease, since the
rebase rewrites history already on the remote) so you can keep committing to it and run
`gpb` again later. Since it's meant to be run often mid-work, any remaining unstaged or
untracked changes are stashed before the risky part of the sequence and restored at the
end regardless of outcome — if restoring them ever conflicts, they're left safe in the
stash with a warning rather than lost.

```sh
cd ~/code/idp/some-repo   # on a branch you're still actively working on
gpb
```

Works on any branch (no issue-branch naming requirement, unlike `gd`) — running it on
the default branch itself is a no-op error.

---

## Daily Usage

### Making Changes

1. Edit configuration files
2. Apply changes:
   - Work Mac: `nix-rebuild` (defined in `work.nix`)
   - Home Mac: `darwin-rebuild switch --flake ~/.config/nixos-config/darwin#arne-mac`

### Adding Packages

Add to `home.packages` in `../home/darwin.nix` (shared by both machines) or
`../home/common.nix` (shared with the NixOS `gamix` config too):

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
darwin-rebuild switch --flake ~/.config/nixos-config/darwin --rollback
```

### Updating the GitHub PAT

`../home/darwin.nix` exports `GITHUB_PERSONAL_ACCESS_TOKEN` in zsh init by
reading it from the macOS Keychain (service `github-pat`), not from the repo.
To set or rotate it:

```bash
security add-generic-password -a "$USER" -s "github-pat" -w "<new-token>" -U
```

`-U` updates the entry in place if one already exists. Open a new shell (or `exec zsh`) to pick up
the change — no rebuild needed since the value isn't stored in the Nix config.

## File Structure

```
darwin/
├── flake.nix               # Both machines' darwinConfigurations, inputs
├── flake.lock              # Locked dependency versions
├── hosts/
│   ├── work-mac/configuration.nix    # Mac-TM7WHWRD7G system config
│   └── arne-mac/configuration.nix    # arne-mac system config
├── git-issue-workflow.nix   # Shared: gi/gia/gd/gpb + the commit-msg hooks they satisfy
├── work.nix                 # Work Mac only: TV2 tooling, git identity, nix-rebuild, secrets sync
├── README.md                # This file
├── SETUP_GUIDE.md            # Fresh-machine bootstrap runbook (this repo's two machines)
├── GITHUB_SETUP.md           # Repo/remote status and cross-machine sync workflow
└── AGENTS.md / CLAUDE.md     # Instructions for coding agents working in this directory

../nvim/                     # Neovim configuration (shared with gamix), used via ../home/common.nix
│   └── lua/
│       └── config/          # Lua configuration modules
../home/common.nix           # home-manager settings shared with gamix (NixOS): ghostty, starship, neovim, git, ripgrep
../home/darwin.nix           # home-manager settings shared by both Mac hosts only: zsh, k9s, gpg, direnv, colima, etc.
```

## Troubleshooting

### Uninstalling Nix

> **Always run uninstall commands from the stock macOS Terminal.app — never from Ghostty or any
> other terminal/shell installed via Nix.**

Ghostty (`programs.ghostty` in `../home/darwin.nix`) and the active zsh profile are both
Nix-store-managed on these machines. If Nix is uninstalled while running inside a Nix-installed
terminal, the terminal binary and/or shell profile scripts you're actively running from can
disappear or break mid-operation, potentially leaving you with no working shell to finish or
recover from a partial uninstall. Terminal.app and its default shell aren't Nix-managed, so they
keep working regardless of what happens to `/nix`. This applies to any uninstaller:
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

- [Nix Darwin Documentation](https://github.com/LnL7/nix-darwin)
- [Home Manager Documentation](https://nix-community.github.io/home-manager/)
- [NixOS Package Search](https://search.nixos.org/packages)
