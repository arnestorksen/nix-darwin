# GitHub Remote & Cross-Machine Sync

This repo is already published — `origin` is
`git@github.com:arnestorksen/nix-darwin.git` (SSH), and now holds both this
`darwin/` config and the NixOS `gamix` config at the repo root. Nothing to set
up here; this doc just covers how the two Mac machines (`Mac-TM7WHWRD7G` /
work, `arne-mac` / home) stay in sync through it.

## Pushing Changes (from either machine)

```bash
cd ~/.config/nixos-config
git add .
git commit -m "Update configuration"
git push
```

## Pulling Changes (on the other machine)

```bash
cd ~/.config/nixos-config
git pull
```
Then rebuild — `nix-rebuild` on the work Mac, or
`darwin-rebuild switch --flake ~/.config/nixos-config/darwin#arne-mac` on the home Mac.

## What's Actually in This Repo

Git identity (name, email, signing key) is set per-machine in `flake.nix` —
work Mac via `work.nix` (email, SSH signing key), home Mac via
`programs.git.settings` in `flake.nix` (GPG key ID). Both are already committed to this repo
and public in git history/commits regardless, so there's nothing extra
exposed by them being in `flake.nix` too.

**Not in this repo** (kept private deliberately): the actual SSH/GPG private
keys, 1Password vault contents, and the `dokken-aws-helper` source (a private
TV2 repo referenced as a `git+ssh://` flake input — see
[README.md](./README.md#work-mac-mac-tm7whwrd7g-specifics)).

## Authentication Issues

```bash
ssh -T git@github.com
```
Should greet you as `arnestorksen`. If it doesn't, see the 1Password SSH Agent
troubleshooting in [SETUP_GUIDE.md](./SETUP_GUIDE.md#step-3-machine-specific-prerequisites)
— the same agent used for commit signing is used for this remote's SSH auth.
