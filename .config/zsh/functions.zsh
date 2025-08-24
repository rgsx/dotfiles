# Functions

folder() {
  ## Creates a folder and navigates (cd) to it
  mkdir $1
  cd $1
}

delete() {
  ## Safe delete with trash
  trash --stopOnError $@
}

dirsize() {
  ## List and shows folders on curent Dir by size, or specific folder by name
  if [ -z "$1" ]; then
    du -sh ./*
  else
    du -sh "$@"
  fi | sort -hr
}

list-tree() {
  ## List all alphabetically in recursive tree view
  tree -a --ignore-case -A
}

youtube() {
  ## Custom YouTube download fucntion (yt-dlp) - works for other video sites 
  for url in "$@"; do

    output_name="%(webpage_url_domain)s/%(channel,creator,uploader)s | %(title.0:48)s | %(id.0:16)s.%(ext)s"
    output_dir="$HOME/downloads/↪ Terminal/"
    sort="fps:60,res:1080,hdr:12"
    format='bv*[ext=mp4][vcodec~="^((he|a)vc|h26[45])"]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b'
    #--trim-filenames 128
    yt-dlp --quiet --progress --console-title --no-config-locations --force-overwrites --concurrent-fragments 8 --cookies-from-browser firefox --no-warnings --add-metadata --compat-options embed-metadata $url --format $format --format-sort $sort --output "$output_dir$output_name"

  done
  echo "Done"
}

youtube-batch() {
  ## Custom batch download for YouTube (or other video sites), loads from URL list on a Text file
  output_name="%(webpage_url_domain)s/%(channel,creator,uploader)s | %(title.0:48)s | %(id.0:16)s.%(ext)s"
  output_dir="$HOME/downloads/↪ Terminal/"
# output_dir="/Volumes/External/Library/Webseries/"
  sort="fps:60,res:1080,hdr:12"
  format='bv*[ext=mp4][vcodec~="^((he|a)vc|h26[45])"]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b'

   yt-dlp --quiet --progress --console-title --no-config-locations --no-overwrites --concurrent-fragments 2 --cookies-from-browser firefox --no-warnings --add-metadata --compat-options embed-metadata --batch-file $1 --format $format --format-sort $sort --output "$output_dir$output_name"

}

instagram() {
  ## Custom Intagram downloader function, downloads and converts for iOS/macOS full compatibility
  for url in "$@"; do

    output_file="%(channel,creator,uploader)s | %(title.0:48)s | %(id.0:16)s.%(ext)s"
    output_dir="$HOME/downloads/↪ Terminal/instagram.com/"

    download_file=$(yt-dlp --quiet --progress --console-title --no-config-locations --force-overwrites --concurrent-fragments 8 --restrict-filenames --cookies-from-browser firefox --no-warnings $url --format 'bv*+ba/b' --output "$output_dir$output_file" --print after_move:filepath)

    to_convert="$(basename "$download_file")"

    #echo $to_convert

    ffmpeg -i "$output_dir$to_convert" -c:v libx265 -tag:v hvc1 -crf 20 -pix_fmt yuv420p10le -c:a aac -b:a 160k "$output_dir${to_convert%.*} | converted.mp4" > /dev/null 2>&1

    echo "Done "

  done
}

brewup() {
  ## Homebrew full maintance function
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

setDevFileTypes() {
  ## Sets development files on macOS to be open by VSCode as default 
curl "https://raw.githubusercontent.com/github/linguist/master/lib/linguist/languages.yml" | yq -r "to_entries | (map(.value.extensions) | flatten) - [null] | unique | .[]" | xargs -L 1 -I "{}" duti -s com.microsoft.VSCode {} all 2>&1
echo "Done  "
}

fuzz(){
  ## Complete Fuzzy finder UI with code highlight previews
  git ls-files | fzf --style full \
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

delhist() {
  ## Function to search and delete from the ZSH History
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

# mydefs: list ONLY your own aliases/functions from your zsh files with "##" descriptions;
# Usage: mydefs [filter];
mydefs() {
  ## Gets all Aliases and Functions with their descriptions
  local filter="${1:-}";
  # Edit paths if you keep defs elsewhere; (.N) ignores non-matching globs;
  local files=(
    "$XDG_CONFIG_HOME/zsh/aliases.zsh"
    "$XDG_CONFIG_HOME/zsh/functions.zsh"
  );

local existing=() f;
  for f in "${files[@]}"; do [[ -f "$f" ]] && existing+=("$f"); done;
  if (( ${#existing[@]} == 0 )); then
    echo "No zsh files found to scan."; return 1;
  fi;

  # Colour detection (TTY + tput + NO_COLOR);
  local use_color=0;
  if [[ -t 1 && -z "$NO_COLOR" ]]; then
    if command -v tput >/dev/null 2>&1; then
      [[ "$(tput colors)" -ge 8 ]] && use_color=1;
    else
      use_color=1;
    fi;
  fi;

  # Palette;
  local C_RESET="" C_TITLE="" C_ALIAS="" C_FUNC="" C_DESC="";
  if (( use_color )); then
    C_RESET=$'\033[0m';
    C_TITLE=$'\033[1;36m';   # bold cyan (section titles);
    C_ALIAS=$'\033[32m';     # green (alias names);
    C_FUNC=$'\033[35m';      # magenta (function names);
    C_DESC=$'\033[90m';      # dim (descriptions);
  fi;

  FILT="$filter" C_RESET="$C_RESET" C_TITLE="$C_TITLE" C_ALIAS="$C_ALIAS" C_FUNC="$C_FUNC" C_DESC="$C_DESC" perl -e '
    use strict; use warnings; binmode STDOUT, ":utf8";
    my $filt   = lc($ENV{FILT}//"");
    my $cR     = $ENV{C_RESET}//"";
    my $cT     = $ENV{C_TITLE}//"";
    my $cA     = $ENV{C_ALIAS}//"";
    my $cF     = $ENV{C_FUNC}//"";
    my $cD     = $ENV{C_DESC}//"";

    my (@aliases, @funcs);
    my $prev = "";
    my ($in, $depth, $fname, $fdesc) = (0, 0, "", "");

    while (<>) {
      my $line = $_; chomp $line;
      my $prevdesc = ($prev =~ /^\s*##\s*(.*)\s*$/) ? $1 : "";

      # Aliases;
      if ($line =~ /^\s*alias\s+([A-Za-z0-9_][A-Za-z0-9_-]*)\s*=/) {
        my $name = $1;
        my $desc = "(no description)";
        if    ($line =~ /##\s*(.*)\s*$/) { $desc = $1; }
        elsif ($prevdesc ne "")          { $desc = $prevdesc; }
        my $txt = lc("$name $desc");
        next if $filt ne "" && index($txt, $filt) < 0;
        push @aliases, [$name, $desc];
      }

      # Function start;
      if (!$in && ($line =~ /^\s*([A-Za-z0-9_][A-Za-z0-9_-]*)\s*\(\)\s*\{/
                || $line =~ /^\s*function\s+([A-Za-z0-9_][A-Za-z0-9_-]*)\s*\{/)) {
        $fname = $1; $fdesc = $prevdesc; $in = 1; $depth = 1; $prev = $line; next;
      }

      if ($in) {
        $fdesc = $1 if $fdesc eq "" && $line =~ /^\s*##\s*(.*)\s*$/;
        my $opens  = ($line =~ tr/{//);
        my $closes = ($line =~ tr/}//);
        $depth += $opens - $closes;
        if ($depth <= 0) {
          my $desc = $fdesc ne "" ? $fdesc : "(no description)";
          my $txt  = lc("$fname $desc");
          if ($filt eq "" || index($txt, $filt) >= 0) {
            push @funcs, [$fname, $desc];
          }
          ($in, $depth, $fname, $fdesc) = (0, 0, "", "");
        }
        $prev = $line; next;
      }

      $prev = $line;
    }

    sub print_table {
      my ($title, $rows, $name_color) = @_;
      print $title, "\n";
      if (!@$rows) { print "—\n\n"; return; }
      my $w = 0; for (@$rows) { $w = length($_->[0]) if length($_->[0]) > $w; }
      $w = $w < 4 ? 4 : $w;
      for (@$rows) {
        printf "%s%-*s%s  %s%s%s\n",
          $name_color, $w, $_->[0], $cR, $cD, $_->[1], $cR;
      }
      print "\n";
    }

    print $cT, "\nALIASES", $cR;
    print $cD, "\n-------", $cR, "\n";
    print_table("", \@aliases, $cA);
    print $cT, "FUNCTIONS", $cR;
    print $cD, "\n---------", $cR, "\n";
    print_table("", \@funcs, $cF);
  ' "${existing[@]}";
};
