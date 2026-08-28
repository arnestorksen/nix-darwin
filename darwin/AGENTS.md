# Instructions for agents working in this directory

Scope: this `darwin/` subtree only (the two Mac configs). For the NixOS
`gamix` config at the repo root, plain `nixos-rebuild switch --flake .#gamix`
is fine — none of the caveats below apply there.

## Rebuilding

Always suggest `nix-rebuild` to apply changes on the work Mac — a shell
function (provided by `nix-dokken-dev`, defined in the user's shell profile,
not in this repo) that builds the flake as the user and then runs `sudo
darwin-rebuild activate`.

Do **not** suggest plain `darwin-rebuild switch --flake .#<host>` on the work Mac
(`Mac-TM7WHWRD7G`) — it doesn't work. The flake has a private `nix-dokken-dev` input fetched over
`git+ssh` (currently pointed at a local `git+file://` checkout, see `flake.nix`), which needs the
user's 1Password SSH agent to authenticate; running the build under `sudo` can't reach that agent.
`nix-rebuild` avoids this by building as the user first and only using `sudo` for the activation
step. See [README.md](./README.md#making-changes) for details. On `arne-mac` (no private inputs),
plain `darwin-rebuild switch --flake` is fine.

## Safety: uninstalling Nix

If asked to uninstall Nix, nix-darwin, or run any related uninstaller
(`nix run nix-darwin -- uninstall`, `/nix/nix-installer uninstall`, Determinate's `.pkg`
uninstaller, etc.) on `Mac-TM7WHWRD7G` or `arne-mac` — **warn the user first, and insist the
actual uninstall command be run from the stock macOS Terminal.app, never from Ghostty or any
other terminal/shell installed via Nix.**

Why: Ghostty (`programs.ghostty` in `../home/common.nix`) and the active zsh profile are both
Nix-store-managed on these machines. Uninstalling Nix from inside a Nix-installed terminal can
make the terminal binary or shell profile scripts you're actively running from disappear or break
mid-operation, potentially leaving no working shell to finish or recover from a partial uninstall.
Terminal.app and its default shell aren't Nix-managed, so they keep working regardless of what
happens to `/nix`.

See [README.md](./README.md#uninstalling-nix) for the user-facing version of this warning.
