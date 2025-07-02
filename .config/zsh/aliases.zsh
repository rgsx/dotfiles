# Aliases
alias ok="exit"
alias ls='ls --color'
alias vim='nvim'
alias rm="safe-rm"
alias colours='msgcat --color=test'
alias unquarantine='xattr -d com.apple.quarantine'
alias edit="$EDITOR"
alias configs="cd $XDG_CONFIG_HOME"
alias starship-config="edit $STARSHIP_CONFIG"
alias zsh-config="edit $XDG_CONFIG_HOME/zsh/zshrc"
alias kitty-config="edit $XDG_CONFIG_HOME/kitty/kitty.conf"
alias ghostty-config="edit $XDG_CONFIG_HOME/ghostty/config"
alias zsh-aliases="edit $XDG_CONFIG_HOME/zsh/aliases.zsh"
alias zsh-functions="edit $XDG_CONFIG_HOME/zsh/functions.zsh"
alias zsh-plugins="edit $XDG_CONFIG_HOME/zsh/plugins.zsh"
alias zsh-env="edit $XDG_CONFIG_HOME/zsh/zshenv"

alias list="eza --oneline --long --tree --classify=always --color=auto --icons=always --hyperlink --all --level=0 --sort=type --group-directories-first --git --no-permissions --no-filesize --no-user --no-time"

alias git-sign-on="git config commit.gpgsign true && git config user.signingkey 40D24CB579AE8FE8" #turning on signing commits by repo

alias git-sign-off="git config --unset commit.gpgsign && git config --unset user.signingkey" #turning off signing commits by repo

alias getMacAddress='
echo "Wi-Fi:" && ifconfig en0 | awk "/ether/ {print \$2}";
echo "LAN:" && ifconfig en1 | awk "/ether/ {print \$2}"'

alias getHostname='echo "Hostname:" && hostname'

alias symlinkJava="sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk"
