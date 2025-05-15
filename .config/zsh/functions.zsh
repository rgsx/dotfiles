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

list-tree() {
  tree -a --ignore-case -A
}

youtube() {
  for url in "$@"; do

    #output="$HOME/downloads/%(id)s.%(ext)s"
    output="$HOME/downloads/↪ Terminal/%(id)s.%(ext)s"
    sort="fps:60,res:1080,hdr:12"
    format='bv*[ext=mp4][vcodec~="^((he|a)vc|h26[45])"]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b'

    yt-dlp --quiet --progress --console-title --no-config-locations --trim-filenames 128 --force-overwrites --concurrent-fragments 2 --restrict-filenames --cookies-from-browser firefox --no-warnings $url --format $format --format-sort $sort --output $output

  done
  echo "Done"
}

instagram() {
  for url in "$@"; do

    output="$HOME/downloads/↪ Terminal/%(id)s.%(ext)s"

    yt-dlp --quiet --progress --console-title --no-config-locations --trim-filenames 128 --force-overwrites --concurrent-fragments 2 --restrict-filenames --cookies-from-browser firefox --no-warnings $url --format 'bv*+ba/b' --output $output

  done
  echo "Done"
}

brewup() {
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

  echo "${green}Brew complete  ${reset}"
}
