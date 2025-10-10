# Git Authentication Setup with GitHub CLI

## Overview

This document explains how to set up Git authentication using GitHub CLI (`gh`) in the Diamonds project development environment.

## Problem

When using HTTPS remotes with Git, you may encounter authentication errors:

```bash
fatal: could not read Username for 'https://github.com': terminal prompts disabled
```

This occurs because Git cannot prompt for credentials in certain environments (like DevContainers or CI/CD pipelines).

## Solution

The Diamonds project uses GitHub CLI (`gh`) as a credential helper for Git authentication. This allows seamless authentication without manual password entry.

### Automatic Setup

The setup is automatically configured when you run:

```bash
bash .devcontainer/scripts/setup-security.sh
```

This script:
1. Checks if GitHub CLI is installed
2. Verifies you're authenticated with `gh auth login`
3. Configures Git to use GitHub CLI as the credential helper
4. Validates the configuration

### Manual Setup

If you need to set this up manually:

1. **Authenticate with GitHub CLI:**
   ```bash
   gh auth login
   ```
   
   Follow the prompts to authenticate. Choose:
   - **GitHub.com** (not GitHub Enterprise)
   - **HTTPS** as the preferred protocol
   - Authenticate via web browser or token

2. **Configure Git to use GitHub CLI:**
   ```bash
   gh auth setup-git
   ```

3. **Verify the configuration:**
   ```bash
   git config --global --list | grep credential
   ```
   
   You should see:
   ```
   credential.https://github.com.helper=!/usr/bin/gh auth git-credential
   credential.https://gist.github.com.helper=!/usr/bin/gh auth git-credential
   ```

### Verification

Test that authentication works:

```bash
git push --dry-run
```

This should complete without authentication errors.

## How It Works

1. When Git needs credentials for GitHub operations, it calls the credential helper
2. The GitHub CLI credential helper (`gh auth git-credential`) is invoked
3. It uses your stored `gh` authentication token
4. No password prompt is needed

## Configuration Details

The GitHub CLI credential helper is configured for:
- `https://github.com` - Main GitHub repositories
- `https://gist.github.com` - GitHub Gists

This configuration is stored in your Git global config (`~/.gitconfig`).

## Troubleshooting

### Not Authenticated

If you see warnings about not being authenticated:

```bash
gh auth status
```

If not logged in, run:

```bash
gh auth login
```

### Configuration Not Working

Re-run the setup:

```bash
gh auth setup-git
```

### Using SSH Instead

If you prefer SSH over HTTPS:

1. Change your remote to use SSH:
   ```bash
   git remote set-url origin git@github.com:your-username/diamonds-project.git
   ```
   
2. a. Ensure your SSH keys are set up:
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
   >> THIS IS A SECURITY RISK: Make sure to protect your private key and use a passphrase. Store keys securely. and never push your keys to any repository.
   b. copy existing keys to `<project-root>/.ssh/id_ed25519` and `<project-root>/.ssh/id_ed25519.pub`.

3. Set up SSH keys with GitHub:
   ```bash
   gh ssh-key add ~/.ssh/id_ed25519.pub
   ```

## References

- [GitHub CLI Authentication](https://cli.github.com/manual/gh_auth)
- [Git Credential Helpers](https://git-scm.com/docs/gitcredentials)
- [GitHub CLI as Git Credential Helper](https://cli.github.com/manual/gh_auth_setup-git)

## Related Scripts

- `.devcontainer/scripts/setup-security.sh` - Automatic Git credential setup
- `.husky/pre-push` - Pre-push hooks that require authentication
