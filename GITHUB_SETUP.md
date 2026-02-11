# Publishing to GitHub

## Quick Setup

### 1. Create GitHub Repository

Go to [github.com/new](https://github.com/new) and create a new repository:

- **Name:** `nix-darwin` (or any name you prefer)
- **Description:** "My declarative macOS configuration with nix-darwin"
- **Visibility:** Public (recommended) or Private
- **DO NOT** initialize with README, .gitignore, or license (we already have these)

### 2. Add Remote and Push

Replace `YOUR_USERNAME` with your GitHub username:

```bash
cd ~/.config/nix-darwin

# Add GitHub as remote
git remote add origin https://github.com/YOUR_USERNAME/nix-darwin.git

# Push to GitHub
git push -u origin main
```

### 3. Update Documentation

After creating the repo, update the clone URL in:
- `README.md` (line 32)
- `SETUP_GUIDE.md` (line 45)

Replace `YOUR_USERNAME` with your actual GitHub username.

Then commit and push the changes:

```bash
git add README.md SETUP_GUIDE.md
git commit -m "Update repository URLs"
git push
```

## Using SSH Instead of HTTPS

If you prefer SSH authentication:

```bash
# Add SSH remote instead
git remote add origin git@github.com:YOUR_USERNAME/nix-darwin.git

# Push
git push -u origin main
```

## Setting Up on Second Mac

Once pushed to GitHub, on your other Mac:

```bash
# After installing Nix (see SETUP_GUIDE.md step 1)
git clone https://github.com/YOUR_USERNAME/nix-darwin.git ~/.config/nix-darwin
cd ~/.config/nix-darwin

# Customize for the new machine (see SETUP_GUIDE.md step 3)
# Then build
nix run nix-darwin -- switch --flake ~/.config/nix-darwin
```

## Keeping Configs in Sync

### Pushing Changes from Mac #1

```bash
cd ~/.config/nix-darwin
git add .
git commit -m "Update package list"
git push
```

### Pulling Changes on Mac #2

```bash
cd ~/.config/nix-darwin
git pull
darwin-rebuild switch --flake ~/.config/nix-darwin
```

## Privacy Considerations

### What to Share Publicly

✅ Safe to share:
- Nix configuration files
- Package lists
- Editor configurations
- Shell setup

### What to Keep Private

❌ Don't commit:
- SSH keys
- API tokens
- Passwords or secrets
- Personal documents

**Note:** Your git email and name are in `home.nix` - this is fine since they're already public in your commits.

## Alternative: Private Repository

If you prefer to keep your config private:

1. Create a **private** repository on GitHub
2. The process is the same, but only you can see it
3. You'll need to authenticate on each machine (use GitHub CLI or SSH keys)

## Repository Badge (Optional)

Add this to the top of your README.md for a nice badge:

```markdown
[![Built with Nix](https://img.shields.io/badge/Built_With-Nix-5277C3.svg?logo=nixos&labelColor=73C3D5)](https://nixos.org)
```

## Example Repositories

For inspiration, check out other public nix-darwin configs:
- Search GitHub for "nix-darwin dotfiles"
- Look at the "nix-darwin" topic on GitHub

## Troubleshooting

### Authentication Failed

If using HTTPS and you get authentication errors:
```bash
# Use GitHub CLI for authentication
gh auth login
```

Or switch to SSH:
```bash
git remote set-url origin git@github.com:YOUR_USERNAME/nix-darwin.git
```

### Accidentally Committed Secrets

If you accidentally commit secrets:
1. Remove the file and commit
2. Push the changes
3. **Important:** Rotate the leaked credentials immediately
4. Consider using `git filter-branch` or BFG Repo-Cleaner to remove from history

For sensitive configs, consider using tools like:
- `sops-nix` for encrypted secrets
- `agenix` for age-encrypted secrets in Nix
