# Complete Nix Darwin Setup Recipe

A step-by-step guide to set up this exact configuration on a new Mac.

## Prerequisites

- macOS (tested on Apple Silicon)
- Terminal access
- Internet connection

## Step-by-Step Installation

### Step 1: Install Nix (Choose One Method)

#### Option A: Determinate Nix Installer (Recommended)

This installer is cleaner and easier to uninstall:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

#### Option B: Official Nix Installer

The traditional method:

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

**After installation:**
1. Close your terminal completely
2. Open a new terminal window
3. Verify installation: `nix --version`

### Step 2: Clone Configuration

```bash
# Create config directory
mkdir -p ~/.config

# Clone this repository
git clone https://github.com/YOUR_USERNAME/nix-darwin.git ~/.config/nix-darwin

# Navigate to the directory
cd ~/.config/nix-darwin
```

### Step 3: Customize Configuration

#### 3a. Find Your Hostname

```bash
hostname
```

#### 3b. Edit flake.nix

Open `flake.nix` and add/update your machine's configuration:

```nix
darwinConfigurations."YOUR-HOSTNAME" = mkDarwinConfig "YOUR-HOSTNAME" "YOUR-USERNAME";
```

For example, if your hostname is "MacBook-Pro" and username is "john":

```nix
darwinConfigurations."MacBook-Pro" = mkDarwinConfig "MacBook-Pro" "john";
```

#### 3c. Edit home.nix

Update these values:

```nix
home.username = "YOUR-USERNAME";
home.homeDirectory = "/Users/YOUR-USERNAME";
```

And your git configuration:

```nix
programs.git = {
  enable = true;
  userName = "Your Name";
  userEmail = "your.email@example.com";
};
```

#### 3d. Edit configuration.nix (if needed)

Update the user definition:

```nix
users.users.YOUR-USERNAME = {
  name = "YOUR-USERNAME";
  home = "/Users/YOUR-USERNAME";
};
```

### Step 4: First-Time Build

Run the initial build (this will take a while). Note: Recent versions of nix-darwin require running the initial activation as root.

```bash
sudo nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake '/Users/YOUR-USERNAME/.config/nix-darwin#YOUR-HOSTNAME'
```

For example, if your hostname is "arne-mac" and username is "arne":

```bash
sudo nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake '/Users/arne/.config/nix-darwin#arne-mac'
```

**Important notes:**
- Use `sudo` for the initial installation (required for system activation)
- Use absolute path, not `~` (tilde)
- Quote the flake reference to prevent shell interpretation of `#`
- Specify your configuration name after `#` (must match what you defined in flake.nix)
- You'll see a warning about $HOME ownership - this is normal when using sudo

This command:
- Downloads nix-darwin
- Builds your system configuration
- Sets up system profiles
- Activates the configuration

### Step 5: Restart Your Terminal

Close and reopen your terminal to load the new shell configuration.

### Step 6: Verify Installation

Check that everything is working:

```bash
# Check Darwin rebuild is available
which darwin-rebuild

# Check installed packages
which starship git gh kubectl docker

# Check zsh configuration
echo $SHELL
```

### Step 7: Future Updates

After the initial installation, you no longer need `sudo` for regular updates. Use this command to rebuild:

```bash
darwin-rebuild switch --flake ~/.config/nix-darwin
```

Or specify the configuration explicitly:

```bash
darwin-rebuild switch --flake '~/.config/nix-darwin#arne-mac'
```

## What Gets Installed

### System Configuration
- Nix with flakes enabled
- Unfree packages allowed (for tools like Terraform)

### Shell & Terminal
- Zsh as default shell
- Starship prompt
- Antidote plugin manager
- Direnv for project environments
- FZF for fuzzy finding

### Development Tools
- Git + Git LFS + GitHub CLI
- Neovim with full IDE setup
  - LSP support (Go, Terraform, YAML, Bash)
  - Treesitter syntax highlighting
  - Telescope fuzzy finder
  - File explorer and more

### DevOps Tools
- Docker + Docker Compose + Colima
- Kubernetes: kubectl, kustomize, kubelogin, kubectx, k9s
- Terraform + Terraform LSP
- AWS CLI

### Utilities
- ripgrep, tree, jq, yq
- wget, curl
- GNU grep and coreutils

## Common Issues & Solutions

### Issue: "darwin-rebuild: command not found"

**Solution:** Restart your terminal or source your profile:
```bash
source ~/.zshrc
```

### Issue: "error: getting status of '/nix/store/...': No such file or directory"

**Solution:** Your git repository has untracked files. Flakes only see committed files:
```bash
git add .
git commit -m "Update configuration"
```

### Issue: "system activation must now be run as root"

**Solution:** Recent versions of nix-darwin require sudo for the initial installation. Use:
```bash
sudo nix run nix-darwin --extra-experimental-features "nix-command flakes" -- switch --flake '/Users/YOUR-USERNAME/.config/nix-darwin#YOUR-HOSTNAME'
```
After the first successful installation, regular updates with `darwin-rebuild` don't need sudo.

### Issue: Different hostname on new machine

**Solution:** Either:
1. Add a new configuration in `flake.nix` for the new hostname, or
2. Specify the configuration explicitly:
   ```bash
   darwin-rebuild switch --flake '~/.config/nix-darwin#BGOMAC-ars'
   ```
   Note: Quote the flake reference to prevent shell interpretation of `#`

## Tips for Multiple Machines

### Option 1: Same Configuration Everywhere

Use the same hostname-specific configuration by specifying it:

```bash
darwin-rebuild switch --flake '~/.config/nix-darwin#BGOMAC-ars'
```

### Option 2: Machine-Specific Configurations

Add different configurations for each machine in `flake.nix`:

```nix
darwinConfigurations = {
  "work-laptop" = mkDarwinConfig "work-laptop" "ars";
  "personal-mac" = mkDarwinConfig "personal-mac" "ars";
};
```

Then create separate home.nix files:
- `home-work.nix`
- `home-personal.nix`

### Option 3: Shared Base + Machine-Specific Overrides

Create a `common.nix` with shared config, then import and override per machine.

## Maintenance

### Update all dependencies:
```bash
cd ~/.config/nix-darwin
nix flake update
darwin-rebuild switch --flake .
```

### Clean up old generations:
```bash
nix-collect-garbage -d
```

### See what changed:
```bash
darwin-rebuild --list-generations
```

## Next Steps

1. Customize package list in `home.nix`
2. Tweak Neovim configuration in `nvim/lua/config/`
3. Add more Zsh plugins in the `.zsh_plugins.txt` section
4. Configure Starship prompt in `home.nix`

## Getting Help

- Check the [README.md](./README.md) for daily usage
- Browse [Nix Darwin docs](https://github.com/LnL7/nix-darwin)
- Search packages at [search.nixos.org](https://search.nixos.org)
- Join the [NixOS Discourse](https://discourse.nixos.org)
