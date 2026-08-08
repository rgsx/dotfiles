# dotfiles

Personal macOS development environment configs and bootstrap scripts.

## Quick start (fresh machine)

**Before testing:** commit and push this repo so the new machine can clone it.

1. Install Xcode Command Line Tools (GUI prompt):

```bash
xcode-select --install
```

2. Clone via HTTPS (SSH keys do not exist yet on a fresh Mac):

```bash
mkdir -p ~/.dev/_meta
git clone https://github.com/rgsx/dotfiles.git ~/.dev/_meta/dotfiles
```

3. Run bootstrap (interactive; plan for ~30–60 min with brew bundle):

```bash
~/.dev/_meta/dotfiles/scripts/bootstrap.sh --profile macbook_air
```

Phase 0 exits if CLT is missing — complete the dialog, then re-run bootstrap.

4. Open a new terminal:

```bash
exec zsh -l
```

After SSH keys are generated (Phase 7), add public keys to GitHub/GitLab, then optionally switch the remote to SSH:

```bash
cd ~/.dev/_meta/dotfiles
git remote set-url origin git@github.com:rgsx/dotfiles.git
```

## Scripts

| Script | Purpose |
|---|---|
| [`scripts/bootstrap.sh`](scripts/bootstrap.sh) | Full fresh-machine install with phase checks |
| [`scripts/update.sh`](scripts/update.sh) | Idempotent sync (symlinks, brew, volta, nvim) |
| [`scripts/uninstall.sh`](scripts/uninstall.sh) | Undo symlinks; optional cleanup flags |
| [`scripts/ssh-keys.sh`](scripts/ssh-keys.sh) | Generate SSH keys from active profile config |
| [`scripts/cursor-settings.sh`](scripts/cursor-settings.sh) | Symlink Cursor User settings.json to dotfiles |
| [`scripts/cursor-extensions.sh`](scripts/cursor-extensions.sh) | Install Cursor theme extensions via Cursor CLI |

### Bootstrap phases

Each phase runs pre-checks before starting and post-checks before continuing:

0. Prerequisites — Xcode CLT, git
1. Dotfiles and symlinks — machine profile, `$HOME` links
2. Homebrew — install if missing
3. Brew bundle — packages and apps from [`.config/homebrew/brewfile`](.config/homebrew/brewfile) (Cursor, Raycast, Docker Desktop, etc.)
4. Post-brew — git-lfs, OpenJDK link, GPG agent, corepack, Cursor settings link
5. JS toolchains — Volta pins from [`package.json`](package.json)
6. Shell and editor — Zinit, Lazy.nvim sync
7. SSH keys — generate missing keys, print upload checklist

### SSH keys

Keys are generated from the active machine profile in [`.config/ssh/config`](.config/ssh/config):

```bash
./scripts/ssh-keys.sh              # interactive
./scripts/ssh-keys.sh --all        # create all missing keys
./scripts/ssh-keys.sh --fix-perms  # fix permissions only
./scripts/ssh-keys.sh --profile macbook_pro
```

Private keys stay local and are gitignored. Only `.pub` files and configs are tracked.

### Cursor settings

Track Cursor User settings in [`.config/cursor/user/settings.json`](.config/cursor/user/settings.json):

```bash
./scripts/cursor-settings.sh import   # copy current Cursor settings into repo
./scripts/cursor-settings.sh link       # symlink Cursor to repo file
./scripts/cursor-settings.sh status     # check link state
./scripts/cursor-settings.sh unlink     # remove symlink, restore regular file
```

Cursor reads from `~/Library/Application Support/Cursor/User/settings.json`. Restart Cursor after linking.

### Cursor extensions

Do **not** use `vscode` entries in the Brewfile — Homebrew will try to install VS Code and cannot install Cursor-bundled extensions (`anysphere.remote-*`).

Theme extensions install via Cursor CLI:

```bash
./scripts/cursor-extensions.sh
```

Catppuccin themes are managed in [`scripts/lib/cursor-extensions.sh`](scripts/lib/cursor-extensions.sh). Remote SSH/containers ship with Cursor and are verified, not installed.

If VS Code was installed by a failed `brew bundle` run, remove it so `code` does not conflict with Cursor:

```bash
brew uninstall --cask visual-studio-code
```

### Update

```bash
./scripts/update.sh
./scripts/update.sh --dry-run
```

### Uninstall

Removes symlinks and restores backups from `~/.dotfiles-backup/`. Does not remove Xcode or CLT.

```bash
./scripts/uninstall.sh
./scripts/uninstall.sh --brew-cleanup --volta-clean
```

## Symlinks

| `$HOME` | Target |
|---|---|
| `~/.config` | `$DOTFILES/.config` |
| `~/.zshrc` | `~/.config/zsh/zshrc` |
| `~/.zshenv` | `~/.config/zsh/zshenv` |
| `~/.ssh` | `~/.config/ssh` |
| `~/.gitconfig` | `~/.config/git/gitconfig` |
| `~/.gitignore` (via gitconfig) | `~/.config/git/gitignore` |

Git reads the global ignore file from `core.excludesfile` in gitconfig — not from a `~/.gitignore` file in `$HOME`. Every repo, including new ones, picks it up automatically once bootstrap links gitconfig.

## Manual post-install

- Import GPG signing key from secure backup
- Run `gh auth login`
- Install Ghostty and Monaspace fonts
- Restart Cursor after bootstrap links settings (or run `./scripts/cursor-settings.sh link`)
- Run `setDevFileTypes` in zsh to set Cursor as default for dev file types
- Open Docker Desktop once to finish setup
- Sign in to Raycast on first launch

Cursor, Cursor CLI, Raycast, and Docker Desktop install via `brew bundle`. Catppuccin themes install via `./scripts/cursor-extensions.sh` (bootstrap runs this automatically).

## Maintenance

Use the `brewup` zsh function (after shell is loaded) to update Homebrew and refresh the Brewfile.
