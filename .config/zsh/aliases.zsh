# Aliases

## Universal exit command
alias ok="exit"
## Colored default for ls
alias ls='ls --color'
## Vim > Nvim > NVChad (all the same)
alias vim='nvim'
## Safe RM, all gets deleted to trash
alias rm="safe-rm"
## For terminal color testing
alias colours='msgcat --color=test'
## Remove app from Quarantine: "unquarantine ~/Applications/App.app"
alias unquarantine='xattr -d com.apple.quarantine'
## Call for default editor
alias edit="$EDITOR"
## Quick call to configs folder/repo
alias configs="cd $XDG_CONFIG_HOME"
## Quick call to edit Starship configuration
alias starship-config="edit $STARSHIP_CONFIG"
## Quick call to edit ZSH configuration 
alias zsh-config="edit $XDG_CONFIG_HOME/zsh/zshrc"
## Quick call to edit Kitty configuration 
alias kitty-config="edit $XDG_CONFIG_HOME/kitty/kitty.conf"
## Quick call to edit Ghostty configuration
alias ghostty-config="edit $XDG_CONFIG_HOME/ghostty/config"
## Quick call to edit ZSH Aliases 
alias zsh-aliases="edit $XDG_CONFIG_HOME/zsh/aliases.zsh"
## Quick call to edit ZSH Functions 
alias zsh-functions="edit $XDG_CONFIG_HOME/zsh/functions.zsh"
## Quick call to edit ZSH Plugins 
alias zsh-plugins="edit $XDG_CONFIG_HOME/zsh/plugins.zsh"
## Quick call to edit ZSH Enviroment 
alias zsh-env="edit $XDG_CONFIG_HOME/zsh/zshenv"
## Fuzzy finder for code preview (Needs work)
alias nf='fzf -m --preview="bat --color=always {}" --bind "enter:become(nvim {+})"'
## Tree view for current folder with all info
alias list="eza --oneline --long --tree --classify=always --color=auto --icons=always --hyperlink --all --list-dirs --level=1 --sort=type --classify=always --group-directories-first --git --no-permissions --no-filesize --no-user --no-time ."
## Turn on signed commits by repo
alias git-sign-on="git config commit.gpgsign true && git config user.signingkey 40D24CB579AE8FE8" #turning on signing commits by repo
## Turn off signed commits by repo
alias git-sign-off="git config --unset commit.gpgsign && git config --unset user.signingkey" #turning off signing commits by repo
## Get Mac Adress for WiFi and LAN
alias getMacAddress='
echo "Wi-Fi:" && ifconfig en0 | awk "/ether/ {print \$2}";
echo "LAN:" && ifconfig en1 | awk "/ether/ {print \$2}"'
## Get current Hostname
alias getHostname='echo "Hostname:" && hostname'
## Symlink Java from Homebrew
alias symlinkJava="sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk"
