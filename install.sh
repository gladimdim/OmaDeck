#!/bin/bash
# OmaDeck: fixes that make Omarchy great on the Steam Deck.
#
#   curl -fsSL https://raw.githubusercontent.com/gladimdim/OmaDeck/main/install.sh | bash
#
# Downloads (or updates) OmaDeck into ~/.local/share/omadeck and hands over to
# `omadeck setup`. Safe to re-run: fixes you switched off stay off.
# Remove everything again with:
#
#   omadeck uninstall

set -euo pipefail

OMADECK_REPO="${OMADECK_REPO:-https://github.com/gladimdim/OmaDeck.git}"
OMADECK_BRANCH="${OMADECK_BRANCH:-main}"
OMADECK_DIR="${OMADECK_DIR:-$HOME/.local/share/omadeck}"

die() {
  echo "✗ $*" >&2
  exit 1
}

usage() {
  cat <<EOF
OmaDeck: fixes that make Omarchy great on the Steam Deck.

Usage: install.sh [--uninstall] [--force] [--list]

  --uninstall  Turn every fix off and remove OmaDeck
  --force      Install on hardware that is not a Steam Deck
  --list       Show the available fixes and exit
  -h, --help   Show this help
EOF
}

# Print the OmaDeck checkout to use: the directory this script lives in when it
# is run from a clone, otherwise a fresh or updated clone in $OMADECK_DIR.
resolve_root() {
  local self="${BASH_SOURCE[0]:-}"
  if [[ -n $self && -f $self && -x "$(dirname "$self")/bin/omadeck" ]]; then
    (cd "$(dirname "$self")" && pwd)
    return
  fi

  command -v git >/dev/null || die "git is required"
  if [[ -d $OMADECK_DIR/.git ]]; then
    echo ":: Updating OmaDeck in $OMADECK_DIR" >&2
    git -C "$OMADECK_DIR" fetch --quiet --depth 1 origin "$OMADECK_BRANCH" </dev/null
    git -C "$OMADECK_DIR" reset --quiet --hard FETCH_HEAD </dev/null
  else
    echo ":: Downloading OmaDeck to $OMADECK_DIR" >&2
    mkdir -p "$(dirname "$OMADECK_DIR")"
    git clone --quiet --depth 1 --branch "$OMADECK_BRANCH" "$OMADECK_REPO" "$OMADECK_DIR" </dev/null
  fi
  echo "$OMADECK_DIR"
}

main() {
  local cmd=(setup)
  while (($#)); do
    case $1 in
      --uninstall) cmd=(uninstall) ;;
      --list) cmd=(list) ;;
      --force) cmd+=(--force) ;;
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
  [[ ${cmd[0]} == setup ]] || cmd=("${cmd[0]}")

  local root
  root=$(resolve_root)
  exec "$root/bin/omadeck" "${cmd[@]}" </dev/null
}

# Everything runs from main so that `curl | bash` has read the whole script
# before executing any of it.
main "$@"
