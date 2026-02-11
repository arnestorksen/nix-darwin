# Nix Darwin Configuration

My declarative macOS system configuration using nix-darwin and home-manager.

## Features

- **Declarative package management** - All packages defined in code
- **Home Manager** - User environment and dotfiles
- **Neovim** - Fully configured with LSP, Treesitter, and plugins
- **Shell setup** - Zsh with starship prompt, fzf, direnv
- **Development tools** - Go, Terraform, Kubernetes, Docker, and more

## Quick Start on New Mac

### 1. Install Nix

Using the Determinate Nix Installer (recommended):

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Or using the official installer:

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

**Important:** Restart your terminal after installation.

### 2. Clone This Repository

```bash
mkdir -p ~/.config
git clone https://github.com/YOUR_USERNAME/nix-darwin.git ~/.config/nix-darwin
cd ~/.config/nix-darwin
```

### 3. Customize for Your Machine

Edit `flake.nix` and update:
- The hostname (run `hostname` to find yours)
- Your username if different from "ars"

Edit `home.nix` and update:
- `home.username` (line 5)
- `home.homeDirectory` (line 6)
- Git name and email (lines 87-88)

### 4. Build and Apply Configuration

First time setup (creates system profile):

```bash
nix run nix-darwin -- switch --flake ~/.config/nix-darwin
```

After the first time, use:

```bash
darwin-rebuild switch --flake ~/.config/nix-darwin
```

### 5. Restart Terminal

Your new configuration is now active!

## File Structure

```
.
├── flake.nix           # Flake inputs and outputs
├── flake.lock          # Locked dependency versions
├── configuration.nix   # System-level configuration
├── home.nix           # User packages and programs
├── nvim/              # Neovim configuration
│   └── lua/
│       └── config/    # Lua configuration modules
└── README.md          # This file
```

## Daily Usage

### Making Changes

1. Edit configuration files
2. Apply changes:
   ```bash
   darwin-rebuild switch --flake ~/.config/nix-darwin
   ```

### Adding Packages

Add to `home.packages` in `home.nix`:

```nix
home.packages = with pkgs; [
  # Add your package here
  htop
];
```

### Updating Dependencies

```bash
nix flake update
darwin-rebuild switch --flake ~/.config/nix-darwin
```

### Rolling Back

```bash
darwin-rebuild --list-generations
darwin-rebuild switch --flake ~/.config/nix-darwin --rollback
```

## Useful Commands

```bash
# List all generations
darwin-rebuild --list-generations

# Clean old generations (free space)
nix-collect-garbage -d

# Search for packages
nix search nixpkgs <package-name>

# Check what will change
darwin-rebuild build --flake ~/.config/nix-darwin
nix store diff-closures /var/run/current-system ./result
```

## Troubleshooting

### "No such file or directory: darwin-rebuild"

Make sure you've restarted your terminal after first installation.

### Permission errors

Some commands need sudo for system-level changes. The first-time setup command handles this automatically.

### Flake evaluation errors

Make sure all files are committed to git (flakes ignore untracked files by default):
```bash
git add .
```

## Resources

- [Nix Darwin Documentation](https://github.com/LnL7/nix-darwin)
- [Home Manager Documentation](https://nix-community.github.io/home-manager/)
- [NixOS Package Search](https://search.nixos.org/packages)
- [Nix Pills](https://nixos.org/guides/nix-pills/)

## License

Feel free to use this configuration as inspiration for your own setup!
