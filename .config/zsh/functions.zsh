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
   eza --oneline --long --tree --classify=always --color=auto --icons=always --hyperlink --list-dirs --level=1 --sort=type --classify=always --group-directories-first --git --no-permissions --no-filesize --no-user --no-time . $1
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

# Test API ping (GET)
apiping() {
  url="$1";
  if [ -z "$url" ]; then
    echo "No URL provided";
    return 1;
  fi;

  start=$(date +%s%3N);
  status=$(curl -s -o /dev/null -w "%{http_code}" "$url");
  end=$(date +%s%3N);
  time=$((end - start));

  echo "Status: $status | Time: ${time}ms | URL: $url";
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

## Gets all Aliases and Functions with their descriptions
# mydefs: list ONLY your own aliases/functions from your zsh files with "##" descriptions;
# Usage: mydefs [filter];
mydefs() {
  local verbose=0;
  while getopts ":v" opt; do
    case "$opt" in
      v) verbose=1;;
      *) echo "Usage: mydefs [-v] [filter]"; return 1;;
    esac;
  done;
  shift $((OPTIND-1));
  local filter="${1:-}";

  # Edit paths if you keep defs elsewhere; (.N) ignores non-matching globs;
  local files=(
    "$XDG_CONFIG_HOME/zsh/aliases.zsh"
    "$XDG_CONFIG_HOME/zsh/functions.zsh"
    "$XDG_CONFIG_HOME/zsh/zshenv"
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
  local C_RESET="" C_TITLE="" C_ALIAS="" C_FUNC="" C_EXP="" C_DESC="" C_VAL="";
  if (( use_color )); then
    C_RESET=$'\033[0m';
    C_TITLE=$'\033[1;36m';   # bold cyan;
    C_ALIAS=$'\033[32m';     # green;
    C_FUNC=$'\033[35m';      # magenta;
    C_EXP=$'\033[34m';       # blue;
    C_DESC=$'\033[90m';      # dim;
    C_VAL=$'\033[37m';       # light (values);
  fi;

  (( verbose )) && echo "${C_TITLE}⚠ Showing export VALUES — check for secrets.${C_RESET}";

  FILT="$filter" VERBOSE_EXPORTS="$verbose" \
  C_RESET="$C_RESET" C_TITLE="$C_TITLE" C_ALIAS="$C_ALIAS" C_FUNC="$C_FUNC" C_EXP="$C_EXP" C_DESC="$C_DESC" C_VAL="$C_VAL" \
  perl -e '
    use strict; use warnings; binmode STDOUT, ":utf8";
    my $filt = lc($ENV{FILT}//"");
    my $vexp = ($ENV{VERBOSE_EXPORTS}//"0") eq "1";
    my ($cR,$cT,$cA,$cF,$cE,$cD,$cV) = @ENV{qw/C_RESET C_TITLE C_ALIAS C_FUNC C_EXP C_DESC C_VAL/};
    for ($cR,$cT,$cA,$cF,$cE,$cD,$cV) { $_//=q{} }

    my (@aliases, @funcs, @exports);
    my $prev = "";
    my ($in, $depth, $fname, $fdesc) = (0, 0, "", "");

    sub add_row {
      my ($arrref, $name, $desc, $val) = @_;
      return if $name eq "PATH";                    # <<< EXCLUDE PATH outright
      $desc = "(no description)" if !defined($desc) || $desc eq "";
      my $txt = lc("$name $desc");
      return if $filt ne "" && index($txt, $filt) < 0;
      push @$arrref, [$name, $desc, (defined($val)?$val:undef)];
    }

    while (<>) {
      my $line = $_; chomp $line;
      my $prevdesc = ($prev =~ /^\s*##\s*(.*)\s*$/) ? $1 : "";

      # Aliases;
      if ($line =~ /^\s*alias\s+([A-Za-z0-9_][A-Za-z0-9_-]*)\s*=/) {
        my $name = $1;
        my $desc = ($line =~ /##\s*(.*)\s*$/) ? $1 : $prevdesc;
        add_row(\@aliases, $name, $desc);
      }

      # Exported vars: export ... / typeset|declare -x ...;
      if ($line =~ /^\s*export\b(.*)$/) {
        my $rest = $1;
        my $desc = ($line =~ /##\s*(.*)\s*$/) ? $1 : $prevdesc;
        for my $tok (grep { length } split /\s+/, $rest) {
          next if $tok =~ /^-/;
          $tok =~ s/[;&|]+$//;
          my $name = "";
          if ($tok =~ /^([A-Za-z_][A-Za-z0-9_]*)\s*(?:\+?=|$)/) { $name = $1; }
          next unless $name ne "";
          next if $name eq "PATH";                 # <<< EXCLUDE PATH
          my $val = $vexp ? (exists $ENV{$name} ? $ENV{$name} : "(unset)") : undef;
          add_row(\@exports, $name, $desc, $val);
        }
      }
      elsif ($line =~ /^\s*(typeset|declare)\b(.*)$/) {
        my ($kw, $rest) = ($1, $2);
        my $desc = ($line =~ /##\s*(.*)\s*$/) ? $1 : $prevdesc;
        next unless $rest =~ /-[A-Za-z-]*x/;
        $rest =~ s/^[ \t]*-[A-Za-z-]+[ \t]*//;
        for my $tok (grep { length } split /\s+/, $rest) {
          next if $tok =~ /^-/;
          $tok =~ s/[;&|]+$//;
          my $name = "";
          if ($tok =~ /^([A-Za-z_][A-Za-z0-9_]*)\s*(?:\+?=|$)/) { $name = $1; }
          next unless $name ne "";
          next if $name eq "PATH";                 # <<< EXCLUDE PATH
          my $val = $vexp ? (exists $ENV{$name} ? $ENV{$name} : "(unset)") : undef;
          add_row(\@exports, $name, $desc, $val);
        }
      }

      # Functions;
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
          add_row(\@funcs, $fname, $fdesc);
          ($in, $depth, $fname, $fdesc) = (0, 0, "", "");
        }
        $prev = $line; next;
      }

      $prev = $line;
    }

    sub pad { my ($s,$w)=@_; $s//=q{}; my $l=length($s); return $s . (" " x ($w>$l?$w-$l:0)); }

    sub print_table {
      my ($title, $rows, $name_color, $want_value) = @_;
      print $cT, $title, $cR, "\n";
      if (!@$rows) { print "—\n\n"; return; }

      my ($wname,$wval)=(4,0);
      for (@$rows) {
        $wname = length($_->[0]) if length($_->[0]) > $wname;
        if ($want_value) {
          my $v = defined $_->[2] ? $_->[2] : "";
          $wval = length($v) if length($v) > $wval;
        }
      }

      for (@$rows) {
        my ($n,$d,$v)=@$_;
        $v = "" unless $want_value;
        my $line = sprintf("%s%s%s", $name_color, pad($n,$wname), $cR);
        if ($want_value) { $line .= "  " . $cV . pad($v,$wval) . $cR; }
        $line .= "  " . $cD . $d . $cR;
        print $line, "\n";
      }
      print "\n";
    }

    print_table("\nALIASES",   \@aliases, $cA, 0);
    print_table("\nFUNCTIONS", \@funcs,   $cF, 0);
    my $etitle = $vexp ? "\nEXPORTS" : "EXPORTS";
    print_table($etitle, \@exports, $cE, $vexp);
  ' "${existing[@]}";
};
