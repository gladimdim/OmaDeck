#!/bin/bash
# OmaDeck: fixes that make Omarchy great on the Steam Deck.
#
#   curl -fsSL https://raw.githubusercontent.com/gladimdim/OmaDeck/main/install.sh | bash
#
# Safe to re-run: it updates OmaDeck and re-applies every fix in place.
# Remove everything again with:
#
#   ~/.local/share/omadeck/install.sh --uninstall

set -euo pipefail

OMADECK_REPO="${OMADECK_REPO:-https://github.com/gladimdim/OmaDeck.git}"
OMADECK_BRANCH="${OMADECK_BRANCH:-main}"
OMADECK_DIR="${OMADECK_DIR:-$HOME/.local/share/omadeck}"

# ---------------------------------------------------------------------------
# Output helpers (also available to every fix)
# ---------------------------------------------------------------------------

if [[ -t 1 ]]; then
  BOLD=$'\e[1m' DIM=$'\e[2m' RED=$'\e[31m' GREEN=$'\e[32m' YELLOW=$'\e[33m' BLUE=$'\e[34m' RESET=$'\e[0m'
else
  BOLD="" DIM="" RED="" GREEN="" YELLOW="" BLUE="" RESET=""
fi

info() { echo "${BLUE}::${RESET} $*"; }
ok() { echo "${GREEN}✓${RESET} $*"; }
warn() { echo "${YELLOW}!${RESET} $*" >&2; }
die() {
  echo "${RED}✗${RESET} $*" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Config helpers (available to every fix)
# ---------------------------------------------------------------------------

# Remove the block that put_lua_block wrote for <id>, if any.
remove_lua_block() {
  local file=$1 id=$2
  [[ -f $file ]] || return 0
  sed -i "/^-- >>> omadeck: $id >>>\$/,/^-- <<< omadeck: $id <<<\$/d" "$file"
  # Drop the trailing blank lines the block leaves behind.
  sed -i -e ':a' -e '/^\n*$/{$d;N;ba' -e '}' "$file"
}

# Append <content> to a Lua config file between OmaDeck markers, replacing an
# earlier copy of the same block so re-running stays idempotent.
put_lua_block() {
  local file=$1 id=$2 content=$3
  remove_lua_block "$file" "$id"
  printf '\n-- >>> omadeck: %s >>>\n%s\n-- <<< omadeck: %s <<<\n' "$id" "$content" "$id" >>"$file"
}

# True when this shell can talk to a running Hyprland session.
in_hyprland() {
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && hyprctl version >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Installer
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
${BOLD}OmaDeck${RESET}: fixes that make Omarchy great on the Steam Deck.

Usage: install.sh [--uninstall] [--force] [--list]

  --uninstall  Remove every OmaDeck fix and restore the defaults
  --force      Run on hardware that is not a Steam Deck
  --list       Show the available fixes and exit
  -h, --help   Show this help
EOF
}

is_steam_deck() {
  local vendor product
  vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
  product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
  # Jupiter is the LCD model, Galileo the OLED.
  [[ $vendor == "Valve" && $product =~ ^(Jupiter|Galileo)$ ]]
}

# Print the OmaDeck checkout to use: the directory this script lives in when it
# is run from a clone, otherwise a fresh or updated clone in $OMADECK_DIR.
resolve_root() {
  local self="${BASH_SOURCE[0]:-}"
  if [[ -n $self && -f $self && -d "$(dirname "$self")/fixes" ]]; then
    (cd "$(dirname "$self")" && pwd)
    return
  fi

  command -v git >/dev/null || die "git is required"
  if [[ -d $OMADECK_DIR/.git ]]; then
    info "Updating OmaDeck in $OMADECK_DIR" >&2
    git -C "$OMADECK_DIR" fetch --quiet --depth 1 origin "$OMADECK_BRANCH" </dev/null
    git -C "$OMADECK_DIR" reset --quiet --hard FETCH_HEAD </dev/null
  else
    info "Downloading OmaDeck to $OMADECK_DIR" >&2
    mkdir -p "$(dirname "$OMADECK_DIR")"
    git clone --quiet --depth 1 --branch "$OMADECK_BRANCH" "$OMADECK_REPO" "$OMADECK_DIR" </dev/null
  fi
  echo "$OMADECK_DIR"
}

# Run one hook (fix_install or fix_uninstall) of every fix, each in its own
# subshell so a fix cannot leak state into the next one.
run_fixes() {
  local root=$1 hook=$2 fix status failed=0
  for fix in "$root"/fixes/*/; do
    fix=${fix%/}
    [[ -f $fix/fix.sh ]] || continue
    # Not `if ! ( ... )`: bash ignores set -e inside a condition, so a fix
    # would carry on past its own errors.
    set +e
    (
      set -e
      FIX_DIR=$fix
      # shellcheck source=/dev/null
      source "$fix/fix.sh"
      echo
      echo "${BOLD}$FIX_NAME${RESET} ${DIM}($(basename "$fix"))${RESET}"
      "$hook"
    ) </dev/null
    status=$?
    set -e
    if ((status != 0)); then
      warn "$(basename "$fix") failed"
      failed=1
    fi
  done
  return $failed
}

list_fixes() {
  local root=$1 fix
  for fix in "$root"/fixes/*/; do
    (
      # shellcheck source=/dev/null
      source "$fix/fix.sh"
      echo "${BOLD}$FIX_NAME${RESET} ${DIM}($(basename "$fix"))${RESET}"
      echo "  $FIX_DESCRIPTION"
    )
  done
}

main() {
  local action=install force=0
  while (($#)); do
    case $1 in
      --uninstall) action=uninstall ;;
      --list) action=list ;;
      --force) force=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  ((EUID != 0)) || die "Run OmaDeck as your normal user, not root (it configures your own desktop)"

  local root
  root=$(resolve_root)

  if [[ $action == list ]]; then
    list_fixes "$root"
    exit 0
  fi

  if [[ $action == install ]]; then
    if ! is_steam_deck; then
      ((force)) || die "This does not look like a Steam Deck. Re-run with --force to install anyway."
      warn "Not a Steam Deck; installing anyway because of --force"
    fi
    [[ -f $HOME/.config/hypr/hyprland.lua ]] ||
      die "No ~/.config/hypr/hyprland.lua found. OmaDeck needs Omarchy with Hyprland's Lua config (Hyprland 0.55+)."
  fi

  echo "${BOLD}OmaDeck${RESET} ${DIM}$action${RESET}"
  if run_fixes "$root" "fix_$action"; then
    echo
    ok "OmaDeck ${action} finished"
  else
    echo
    die "OmaDeck ${action} finished with errors (see above)"
  fi
}

# Everything runs from main so that `curl | bash` has read the whole script
# before executing any of it.
main "$@"
