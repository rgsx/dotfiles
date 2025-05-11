# Functions

folder() {
  mkdir $1
  cd $1
}

delete() {
  trash --stopOnError $@
}

dirsize() {
  if [ -z "$1" ]; then
    du -sh ./*
  else
    du -sh "$@"
  fi | sort -hr
}

brewup () {
  # Colours
  local red="\033[0;31m"
  local green="\033[0;32m"
  local yellow="\033[1;33m"
  local reset="\033[0m"
  local checkmark=""
  local crossmark="✖"

  local BUNDLE_DIR="$XDG_CONFIG_HOME/homebrew"
  local BUNDLE_PATH="$BUNDLE_DIR/brewfile"

  # Helper to run and report
  run_step() {
    local message="$1"
    shift
    echo -n "${green}${message} ${reset} "

    # Capture both stdout and stderr
    local output
    output="$("$@" 2>&1)"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      echo "${green}${checkmark}${reset}"
    else
      echo "${red}${crossmark} (failed)${reset}"
      echo "${red}${output}${reset}"
      return $status
    fi
  }

  # Ensure directory exists
  if [[ ! -d "$BUNDLE_DIR" ]]; then
    echo "${yellow}Creating config dir at ${BUNDLE_DIR}${reset}"
    mkdir -p "$BUNDLE_DIR" || {
      echo "${red}${crossmark}Failed to create directory${reset}"
      return 1
    }
  fi

  run_step "Running brew diagnostics" brew doctor
  run_step "Checking for missing dependencies" brew missing
  run_step "Updating brew" brew update
  run_step "Checking outdated packages" brew outdated
  run_step "Upgrading packages" brew upgrade
  run_step "Cleaning up" brew cleanup -s
  run_step "Saving Brewfile" \
    brew bundle dump --describe --file="$BUNDLE_PATH" --force

  echo "${green} Brew complete${reset}"
}

