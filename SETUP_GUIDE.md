# Fresh-Machine Bootstrap Runbook

Step-by-step recipe for bringing up one of this repo's two known machines
(`Mac-TM7WHWRD7G` / work, `arne-mac` / home) from a blank macOS install. This is
specific to those two machines — general nix-darwin/home-manager/`nix-dokken-dev`
concepts and options are documented in `nix-dokken-dev`'s own README, not here.
If you're setting up a genuinely new (third) machine, read
[README.md](./README.md#the-two-machines) first and add a new
`darwinConfigurations` block modeled on whichever of the two is the closer match.

## Step 1: Install Nix

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Restart your terminal, then verify: `nix --version`.

You'll likely see `WARN ... SelfTest ShellFailed` for `sh`/`bash` — this is a
known, harmless quirk: Determinate's installer only wires "use Nix in
non-interactive shells" into zsh, which is what both machines use as the login
shell anyway.

You may also see an `INFO` line suggesting Determinate's `.pkg`-based graphical
installer instead. We're intentionally using the shell script — see
[README.md](./README.md#installer-determinate-nix) for why.

## Step 2: Clone This Repository

```bash
mkdir -p ~/.config
git clone git@github.com:arnestorksen/nix-darwin.git ~/.config/nix-darwin
cd ~/.config/nix-darwin
```

## Step 3: Machine-Specific Prerequisites

### Work Mac (`Mac-TM7WHWRD7G`) only

1. **1Password SSH Agent**: enable it in 1Password → Settings → Developer →
   SSH Agent, and confirm you're signed into the correct 1Password
   account/vault (the one containing `SSH Key (TV 2 - git)` in the `Private`
   vault). This is easy to get wrong silently: if you're in the wrong vault,
   `ssh-add -l` against 1Password's agent just reports "no identities" with no
   error pointing at the cause, even though the socket, config, and toggle all
   look correct.

   Verify:
   ```bash
   SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l
   SSH_AUTH_SOCK=~/.1password/agent.sock ssh -T git@github.com
   ```
   The second command should greet you by GitHub username.

2. **FlakeHub sign-in** (for the native Linux builder):
   ```bash
   determinate-nixd auth login
   ```

3. Confirm `~/code/nix-work-env` (the local `nix-dokken-dev` checkout
   `flake.nix` currently points at) exists on this machine, since the input
   isn't pointed at the pushed GitHub repo yet.

### Home Mac (`arne-mac`)

No prerequisites — no private inputs, no 1Password SSH agent dependency.

## Step 4: First-Time Build + Activate

### Home Mac — plain path

```bash
sudo nix run nix-darwin -- switch --flake ~/.config/nix-darwin#arne-mac
```

### Work Mac — private-input-safe path

The plain command above will fail here: `root` (under `sudo`) has no SSH agent
to fetch the private `git+ssh://` `nix-dokken-dev` input. Build as your user
first (SSH agent available), then activate the already-built result as root:

```bash
nix build ~/.config/nix-darwin#darwinConfigurations.Mac-TM7WHWRD7G.system -o /tmp/nix-darwin-system
sudo mv /etc/nix/nix.custom.conf /etc/nix/nix.custom.conf.before-nix-darwin   # only if it exists
sudo /tmp/nix-darwin-system/sw/bin/darwin-rebuild activate
```

**Known gotcha — `home-manager.backupFileExtension` collision:** if this
machine has been set up with this config before (e.g. a previous nix install
that got wiped), activation can fail partway with something like:

```
Existing file '/Users/ars/.zshrc.backup' would be clobbered by backing up '/Users/ars/.zshrc'
```

This happens when a `.backup` file from a *previous* activation already
occupies the path home-manager wants to write the *current* file's backup to.
Check whether the live file is worth preserving (it may just be a throwaway
default file recreated since the last wipe) and whether the existing
`.backup` is the one with real history — then rename the old `.backup` aside
(e.g. `mv ~/.zshrc.backup ~/.zshrc.backup.$(date +%F)`) rather than deleting
either, and retry activation. Repeat for any other conflicting path it reports
(it stops at the first one found).

## Step 5: Restart Your Terminal

## Step 6: Verify

```bash
which darwin-rebuild starship git nvim
echo $SHELL

# Work Mac only:
which nix-rebuild dokken-aws-helper   # nix-rebuild is a shell function, not a binary — use `type nix-rebuild`
cat ~/.ssh/allowed_signers            # should already list your signing key
```

### Verify commit signing (work Mac)

```bash
cd ~/code/some-work-repo
git commit --allow-empty -m "test signing"
git log --show-signature -1
```

## Step 7: Future Updates

- Work Mac: `nix-rebuild` (handles the build-as-user/activate-as-root split automatically)
- Home Mac: `darwin-rebuild switch --flake ~/.config/nix-darwin#arne-mac`

## Maintenance

```bash
cd ~/.config/nix-darwin
nix flake update
# then rebuild as in Step 7

nix-collect-garbage -d       # clean up old generations
darwin-rebuild --list-generations
```

## Getting Help

- General nix-darwin/home-manager/`nix-dokken-dev` concepts, module options,
  Linux builder / sandbox VM setup: see
  [nix-dokken-dev](https://github.com/tv2norge/nix-dokken-dev)'s README
- [Nix Darwin docs](https://github.com/LnL7/nix-darwin)
- [search.nixos.org](https://search.nixos.org)
