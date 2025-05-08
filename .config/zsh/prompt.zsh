# Load Zsh color support (not used anymore, but left here in case you change your mind)
autoload -U colors && colors

# Enable prompt substitution so PROMPT can evaluate variables or commands if needed
setopt prompt_subst

# Set a simple prompt using a chevron ›
function who_prompt {
  PROMPT="› "
}

# Apply the custom prompt immediately
who_prompt

# Define a function that runs when a new command line is initiated
zle-line-init() {
  emulate -L zsh  # Use Zsh behaviour with local scope for options

  # Only run if the editor context is 'start' (new command line)
  [[ $CONTEXT == start ]] || return 0

  # Handle Ctrl-D (EOF) with a recursive edit loop
  while true; do
    zle .recursive-edit       # Start a new nested editing session
    local -i ret=$?           # Capture return status
    [[ $ret == 0 && $KEYS == $'\4' ]] || break  # Break if not Ctrl-D or error
    [[ -o ignore_eof ]] || exit 0               # Exit shell unless ignore_eof is set
  done

  # Temporarily override the prompt while editing
  local saved_prompt=$PROMPT
  local saved_rprompt=$RPROMPT
  PROMPT="%{$fg[white]%}› "
  RPROMPT=''
  zle .reset-prompt           # Refresh prompt display
  PROMPT=$saved_prompt        # Restore original prompt
  RPROMPT=$saved_rprompt

  # Finish the line editing depending on success or error
  if (( ret )); then
    zle .send-break
  else
    zle .accept-line
  fi

  return ret
}

# Register zle-line-init as a Zsh widget so it runs at line start
zle -N zle-line-init
