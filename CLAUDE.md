# Instructions for Claude Code (and any other agent) in this repo

## Safety: uninstalling Nix

If asked to uninstall Nix, nix-darwin, or run any related uninstaller
(`nix run nix-darwin -- uninstall`, `/nix/nix-installer uninstall`, Determinate's `.pkg`
uninstaller, etc.) on `Mac-TM7WHWRD7G` or `arne-mac` — **warn the user first, and insist the
actual uninstall command be run from the stock macOS Terminal.app, never from Ghostty or any
other terminal/shell installed via Nix.**

Why: Ghostty (`programs.ghostty` in `home.nix`) and the active zsh profile are both
Nix-store-managed on these machines. Uninstalling Nix from inside a Nix-installed terminal can
make the terminal binary or shell profile scripts you're actively running from disappear or break
mid-operation, potentially leaving no working shell to finish or recover from a partial uninstall.
Terminal.app and its default shell aren't Nix-managed, so they keep working regardless of what
happens to `/nix`.

See [README.md](./README.md#uninstalling-nix) for the user-facing version of this warning.
