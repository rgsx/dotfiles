# Aliases

## Universal exit command
alias ok="exit"
## Colored default for ls
alias ls='ls --color'
## List all depths alphabetically in recursive tree view
alias list-tree='tree -a --ignore-case -A'
## Vim > Nvim > NVChad (all the same)
alias vim='nvim'
## Safe rm deletion, all gets deleted to trash
alias rm="delete"
## For terminal color testing
alias colours='msgcat --color=test'
## Remove app from Quarantine: "unquarantine App.app"
alias unquarantine='xattr -d com.apple.quarantine'
## Call for default editor
alias edit="$EDITOR"
## Quick call to edit configs folder/repo
alias configs="cd $XDG_CONFIG_HOME && edit ."
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
