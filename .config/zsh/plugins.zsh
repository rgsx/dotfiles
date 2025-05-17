# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add in snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

####
# ZSH function to auto-switch to correct Node version
#   https://gist.github.com/callumlocke/30990e247e52ab6ac1aa98e5f0e5bbf5
#
# - Searches up your directory tree for the closest .nvmrc, just like `nvm use` does.
#
# - If you are already on the right Node version, IT DOES NOTHING, AND PRINTS NOTHING.
#
# - Works correctly if your .nvmrc file contains something relaxed/generic,
#   like "4" or "v12.0" or "stable".
#
# - If an .nvmrc is found but you have no installed version that satisfies it, it
#   prints a clear warning, so you can decide whether you want to run `nvm install`.
#
# - If no .nvmrc is found, it does `nvm use default`.
#
# Recommended: leave your default as something generic,
# e.g. do `nvm alias default stable`
####

auto-switch-node-version() {
  NVMRC_PATH=$(nvm_find_nvmrc)
  CURRENT_NODE_VERSION=$(nvm version)

  if [[ ! -z "$NVMRC_PATH" ]]; then
    # .nvmrc file found!

    # Read the file
    REQUESTED_NODE_VERSION=$(cat $NVMRC_PATH)

    # Find an installed Node version that satisfies the .nvmrc
    MATCHED_NODE_VERSION=$(nvm_match_version $REQUESTED_NODE_VERSION)

    if [[ ! -z "$MATCHED_NODE_VERSION" && $MATCHED_NODE_VERSION != "N/A" ]]; then
      # A suitable version is already installed.

      # Clear any warning suppression
      unset AUTOSWITCH_NODE_SUPPRESS_WARNING

      # Switch to the matched version ONLY if necessary
      if [[ $CURRENT_NODE_VERSION != $MATCHED_NODE_VERSION ]]; then
        nvm use $REQUESTED_NODE_VERSION
      fi
    else
      # No installed Node version satisfies the .nvmrc.

      # Quit silently if we already just warned about this exact .nvmrc file, so you
      # only get spammed once while navigating around within a single project.
      if [[ $AUTOSWITCH_NODE_SUPPRESS_WARNING == $NVMRC_PATH ]]; then
        return
      fi

      # Convert the .nvmrc path to a relative one (if possible) for readability
      RELATIVE_NVMRC_PATH="$(realpath --relative-to=$(pwd) $NVMRC_PATH 2> /dev/null || echo $NVMRC_PATH)"

      # Print a clear warning message
      echo ""
      echo "WARNING"
      echo "  Found file: $RELATIVE_NVMRC_PATH"
      echo "  specifying: $REQUESTED_NODE_VERSION"
      echo "  ...but no installed Node version satisfies this."
      echo "  "
      echo "  Current node version: $CURRENT_NODE_VERSION"
      echo "  "
      echo "  You might want to run \"nvm install\""

      # Record that we already warned about this unsatisfiable .nvmrc file
      export AUTOSWITCH_NODE_SUPPRESS_WARNING=$NVMRC_PATH
    fi
  else
    # No .nvmrc file found.

    # Clear any warning suppression
    unset AUTOSWITCH_NODE_SUPPRESS_WARNING

    # Revert to default version, unless that's already the current version.
    if [[ $CURRENT_NODE_VERSION != $(nvm version default)  ]]; then
      nvm use default
    fi
  fi
}

# Run the above function in ZSH whenever you change directory
#autoload -U add-zsh-hook
#add-zsh-hook chpwd auto-switch-node-version
#auto-switch-node-version
