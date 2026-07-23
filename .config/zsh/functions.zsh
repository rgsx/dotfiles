# Functions

## Creates a folder and navigates (cd) to it
folder() {
  mkdir $1
  cd $1
}

## Creates a folder for each file passed with it's name and then moves it
mkdir-move() {
  for file in "$@"; do
    [ -f "$file" ] || continue  # skip if not a file
    dirname="${file%.*}"
    mkdir -p -- "$dirname"
    mv -- "$file" "$dirname"/
  done
}

## Tree view for current folder with all info
list() {
  eza -1lTA --level=1 --classify=always --color=auto --icons=always --hyperlink=auto --sort=type --git --no-permissions --no-user --no-time --group-directories-first . $1
  }

## Safe delete with trash
delete() {
  local args=()
  for arg in "$@"; do
    case "$arg" in
      -r|-f|-rf|-fr) ;;   # ignore these flags
      *) args+=("$arg") ;;
    esac
  done
  if [ ${#args[@]} -eq 0 ]; then
    echo "delete: missing operand" >&2
    return 1
  fi
  trash --stopOnError "${args[@]}";
}

## List and shows folders on curent Dir by size, or specific folder by name
dirsize() {
  if [ -z "$1" ]; then
    du -sh ./*
  else
    du -sh "$@"
  fi | sort -hr
}

## Backup DIR or File(s) to Zip 
backup() {
  if [ $# -lt 1 ]; then
    echo "Usage: backupZip <path...>";
    return 1;
  fi;

  local timestamp=$(date +"%Y%m%d_%H%M%S");
  local out="backup_${timestamp}.zip";

  # -r handles directories; files are added normally
  zip -r "$out" "$@" >/dev/null;

  echo "Backup created: $out";
};

## Custom YouTube download fucntion (yt-dlp) - works for other video sites 
youtube() {
  for url in "$@"; do
    output_name="%(webpage_url_domain)s/%(channel,creator,uploader)s | %(title.0:48)s | %(id.0:16)s.%(ext)s"
    output_dir="$HOME/downloads/↪ Terminal/"
    sort="fps:60,res:1080,hdr:12"
    format='bv*[ext=mp4][vcodec~="^((he|a)vc|h26[45])"]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b'
    #--trim-filenames 128
    yt-dlp --ignore-errors --quiet --progress --console-title --no-config-locations --force-overwrites --concurrent-fragments 8 --cookies-from-browser firefox --no-warnings --sleep-interval 5 --max-sleep-interval 60 --add-metadata --compat-options embed-metadata $url --format $format --format-sort $sort --output "$output_dir$output_name"
  done
  echo "Done"
}

## Custom batch download for YouTube (or other video sites), loads from URL list on a Text file
youtube-batch() {
  output_name="%(webpage_url_domain)s/%(channel,creator,uploader)s | %(title.0:48)s | %(id.0:16)s.%(ext)s"
  output_dir="$HOME/downloads/↪ Terminal/"
# output_dir="/Volumes/External/Library/Webseries/"
  sort="fps:60,res:1080,hdr:12"
  format='bv*[ext=mp4][vcodec~="^((he|a)vc|h26[45])"]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b'

   yt-dlp --quiet --progress --console-title --no-config-locations --no-overwrites --concurrent-fragments 2 --cookies-from-browser firefox --no-warnings --add-metadata --compat-options embed-metadata --batch-file $1 --format $format --format-sort $sort --output "$output_dir$output_name"

}

## Custom Intagram downloader function, downloads and converts for iOS/macOS full compatibility
instagram() {
  for url in "$@"; do
    output_file="%(channel,creator,uploader)s | %(title.0:48)s | %(id.0:16)s.%(ext)s"
    output_dir="$HOME/downloads/↪ Terminal/instagram.com/"
    download_file=$(yt-dlp --quiet --progress --console-title --no-config-locations --force-overwrites --concurrent-fragments 8 --restrict-filenames --cookies-from-browser safari --no-warnings $url --format 'bv*+ba/b' --output "$output_dir$output_file" --print after_move:filepath)
    to_convert="$(basename "$download_file")"
    #echo $to_convert
    ffmpeg -i "$output_dir$to_convert" -c:v libx265 -tag:v hvc1 -crf 20 -pix_fmt yuv420p10le -c:a aac -b:a 160k "$output_dir${to_convert%.*} | converted.mp4" > /dev/null 2>&1
    echo "Done "
  done
}

## Convert video to an iOS compatible mp4
convertToMp4() {
 ffmpeg -i "$1" -c:v libx265 -tag:v hvc1 -crf 20 -pix_fmt yuv420p10le -c:a aac -b:a 160k "${1%.*} | converted.mp4" 
}

## Homebrew full maintance function
brewup() {
  export PATH="/opt/homebrew/bin:$PATH"
  # Colours
  local red="\033[0;31m"
  local green="\033[0;32m"
  local yellow="\033[1;33m"
  local reset="\033[0m"
  local checkmark=""
  local crossmark="✖"
  # Paths
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

## Sets development files on macOS to be open by VSCode as default 
setDevFileTypesOld() {
curl "https://raw.githubusercontent.com/github/linguist/master/lib/linguist/languages.yml" | yq -r "to_entries | (map(.value.extensions) | flatten) - [null] | unique | .[]" | xargs -L 1 -I "{}" duti -s com.microsoft.VSCode {} all 2>&1
echo "Done  "
}

## Set dev file types on macOS to open with a given editor (Cursor by default)
setDevFileTypes() {
  local APP_NAME="${1:-Cursor}";
  local BID;

  # Ensure deps exist
  for bin in curl yq duti osascript; do
    command -v "$bin" >/dev/null 2>&1 || { echo "Missing '$bin'. Install it first (brew install $bin);"; return 1; };
  done;

  # Resolve the bundle identifier dynamically
  BID="$(osascript -e "id of app \"${APP_NAME}\"" 2>/dev/null)" || { echo "App '${APP_NAME}' not found. Is it installed?"; return 1; };

  echo "Using ${APP_NAME} (${BID}) as default for dev file types…";

  # Pull extensions from linguist and assign via duti
  curl -fsSL "https://raw.githubusercontent.com/github/linguist/master/lib/linguist/languages.yml" \
  | yq -r "to_entries | (map(.value.extensions) | flatten) - [null] | unique | .[]" \
  | xargs -L 1 -I "{}" duti -s "${BID}" {} all 2>&1;

  echo "Done  ";
};

## Complete Fuzzy finder UI with code highlight previews
fuzz(){
  git ls-files | fzf -m --style full \
    --input-label ' Search ' --header-label ' File Type ' \
    --preview 'fzf-preview.sh {}' \
    --bind 'result:transform-list-label:
        if [[ -z $FZF_QUERY ]]; then
          echo " $FZF_MATCH_COUNT items "
        else
          echo " $FZF_MATCH_COUNT matches for [$FZF_QUERY] "
        fi
        ' \
    --bind 'focus:transform-preview-label:[[ -n {} ]] && printf " Previewing [%s] " {}' \
    --bind 'focus:+transform-header:file --brief {} || echo "No file selected"' \
    --bind 'ctrl-r:change-list-label( Reloading the list )+reload(sleep 2; git ls-files)' \
    --bind  'enter:become(nvim {+})' \
    --color 'border:#9399ba,label:#bac2de' \
    --color 'preview-border:#9399b2,preview-label:#bac2de' \
    --color 'list-border:#9399b2,list-label:#bac2de' \
    --color 'input-border:#9399b2,input-label:#bac2de' \
    --color 'header-border:#9399b2,header-label:#bac2de'
}

## Function to search and delete from the ZSH History
delhist() {
  local force=0;
  while getopts ":f" opt; do
    case "$opt" in
      f) force=1;;
      *) echo "Usage: delhist [-f] <string>"; return 1;;
    esac;
  done;
  shift $((OPTIND-1));

  if [ -z "$1" ]; then
    echo "Usage: delhist [-f] <string>";
    return 1;
  fi;

  local pattern="$1";
  local file="$HOME/.zsh_history";

  # Show matches (literal search)
  local matches;
  matches=$(grep -n -F -- "$pattern" "$file");
  if [ -z "$matches" ]; then
    echo "No matches found for: $pattern";
    return 0;
  fi;

  echo "Found matches:";
  echo "$matches";

  if [ "$force" -ne 1 ]; then
    echo -n "Delete these entries? [y/N]: ";
    read -r answer;
    case "$answer" in
      [yY]|[yY][eE][sS]) ;;
      *) echo "Aborted."; return 0;;
    esac;
  fi;

  # Backup
  cp "$file" "$file.bak";

  # Escape for sed delimiter and slashes
  local esc="$pattern";
  esc=${esc//\\/\\\\};   # backslashes
  esc=${esc//|/\\|};     # delimiter
  esc=${esc//\//\\/};    # slashes

  # Delete & reload (macOS sed needs -i '')
  LC_ALL=C sed -i '' "/$esc/d" "$file";
  fc -R "$file";
  echo "Deleted entries containing: $pattern";
}

## Open Transmission Web UI on the VPS through a local SSH tunnel
vps-transmission() {
  local port="${1:-9091}"
  local url="http://127.0.0.1:${port}/transmission/web/"

  if ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    ssh -fN -L "${port}:127.0.0.1:9091" vps || return 1
  fi

  open "$url"
  echo "Transmission Web UI: $url"
}

## Stop the local SSH tunnel for the VPS Transmission Web UI
vps-transmission-stop() {
  local port="${1:-9091}"
  pkill -f "ssh .*${port}:127.0.0.1:9091.*vps" 2>/dev/null || true
}

## Run transmission-remote against the VPS daemon
vps-tr() {
  ssh vps transmission-remote 127.0.0.1:9091 "$@"
}

## Add one or more torrent URLs/files/magnets to the VPS daemon
vps-tr-add() {
  if [ $# -eq 0 ]; then
    echo "Usage: vps-tr-add <torrent-url|magnet|path> [...]" >&2
    return 1
  fi
  vps-tr -a "$@"
}

## Pull completed VPS torrents to local Downloads with confirmation
vps-torrent-sync() {
  if [[ $# -lt 1 || $1 == -* ]]; then
    echo "Usage: vps-torrent-pull <local-destination> [--delete]" >&2
    return 1
  fi

  local dest="$1"
  local delete_after=0
  if [[ "${2:-}" == "--delete" ]]; then
    delete_after=1
  fi

  local remote_dir="/home/roberto/downloads/torrents/complete"
  local remote_list
  remote_list=$(ssh vps "find ${remote_dir} -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null" 2>/dev/null)

  if [[ -z "$remote_list" ]]; then
    echo "No completed torrents found on VPS."
    return 0
  fi

  mkdir -p "$dest"
  echo "Syncing from: ${remote_dir}"
  echo "Syncing to  : ${dest}"
  echo
  echo "Files to download:"
  echo "$remote_list"
  echo
  echo "DRY RUN:"
  rsync -ahn --progress --ignore-existing -e ssh "vps:${remote_dir}/" "${dest}/"
  echo
  echo "Summary:"
  echo "$remote_list" | wc -l | tr -d ' ' | xargs -I{} echo "{} files queued."

  if [[ $delete_after -eq 1 ]]; then
    echo
    echo "This will DELETE the source files from the VPS after copy."
  fi

  echo
  read -q "REPLY?Continue with copy? [y/N]: "
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    return 1
  fi

  rsync -avh --progress --ignore-existing -e ssh "vps:${remote_dir}/" "${dest}/"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "rsync failed with exit code ${rc}" >&2
    return $rc
  fi

  echo
  echo "Verifying copied files..."
  local failed=0
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ ! -f "${dest}/${file}" ]]; then
      echo "MISSING LOCAL : ${dest}/${file}" >&2
      failed=1
    else
      echo "OK LOCAL      : ${dest}/${file}"
    fi
  done <<< "$remote_list"

  if [[ $failed -ne 0 ]]; then
    echo "Verification failed; source files were NOT deleted." >&2
    return 1
  fi

  if [[ $delete_after -eq 1 ]]; then
    echo
    read -q "REPLY?Delete source files from VPS? [y/N]: "
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Source files kept on VPS."
      return 0
    fi

    ssh vps "cd '${remote_dir}' && rm -f ${(f)remote_list}" || {
      echo "Remote delete failed; check VPS manually." >&2
      return 1
    }
    echo "Deleted source files from VPS."
  fi

  echo
  echo "Done."
  echo "Local  : ${dest}"
  echo "Remote : ${remote_dir}"
}

change-hostname() {
  local new_hostname="$1"
  if [[ -z "$new_hostname" ]]; then
    echo "Usage: change-hostname <new-hostname>" >&2
    return 1
  fi

  echo "Changing hostname to: $new_hostname"

  if [[ "$OSTYPE" == darwin* ]]; then
    sudo scutil --set HostName "$new_hostname"
    sudo scutil --set ComputerName "$new_hostname"
    sudo scutil --set LocalHostName "$new_hostname"
    dscacheutil -flushcache
    echo "Hostname updated on macOS."
  elif [[ "$OSTYPE" == linux-gnu* ]]; then
    sudo hostnamectl set-hostname "$new_hostname"
    echo "Hostname updated on Linux."
  else
    echo "Unsupported OS." >&2
    return 1
  fi
}

git-host() {
  local url host
  url=$(git config --get remote.origin.url 2>/dev/null || git ls-remote --get-url 2>/dev/null || true)
  [[ -z "$url" ]] && { echo "no remote"; return 1; }
  case "$url" in
    *://*) host="${url#*://}"; host="${host%%/*}" ;;
    *)     host="${url%%:*}" ;;
  esac
  host="${host#*@}"
  print -r -- "$host"
}
