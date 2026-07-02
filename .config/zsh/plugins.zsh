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

# Load completions. Use the existing dump when it is fresh, and rebuild it daily.
autoload -Uz compinit
zmodload zsh/stat zsh/datetime 2>/dev/null
if [[ -n ${ZDOTDIR:-} ]]; then
  zcompdump="${ZDOTDIR}/.zcompdump"
else
  zcompdump="${HOME}/.zcompdump"
fi

if [[ -s "$zcompdump" ]] && zstat -H zcompdump_stat +mtime "$zcompdump" 2>/dev/null && \
   (( EPOCHSECONDS - zcompdump_stat[mtime] < 86400 )); then
  compinit -C -d "$zcompdump"
else
  compinit -d "$zcompdump"
fi
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end

zinit cdreplay -q

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --oneline --long --tree --classify=always --color=auto --icons=always --hyperlink --all --level=1 --sort=type --group-directories-first --git --no-permissions --no-filesize --no-user --no-time $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --oneline --long --tree --classify=always --color=auto --icons=always --hyperlink --all --level=1 --sort=type --group-directories-first --git --no-permissions --no-filesize --no-user --no-time $realpath'

