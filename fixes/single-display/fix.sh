# Sourced by install.sh, which provides FIX_DIR and the info/ok/warn and
# put_lua_block/remove_lua_block/in_hyprland helpers.

FIX_NAME="Single display"
FIX_DESCRIPTION="External display connected: Deck screen turns off. Unplugged: Deck screen turns back on."

BIN="$HOME/.local/bin/omadeck-display-switch"
AUTOSTART="$HOME/.config/hypr/autostart.lua"

stop_switcher() {
  pkill -f "$BIN" 2>/dev/null || true
  for _ in {1..20}; do
    pgrep -f "$BIN" >/dev/null || return 0
    sleep 0.1
  done
}

fix_install() {
  local missing=()
  command -v socat >/dev/null || missing+=(socat)
  command -v jq >/dev/null || missing+=(jq)
  if ((${#missing[@]})); then
    info "Installing ${missing[*]}"
    omarchy pkg add "${missing[@]}"
  fi

  install -Dm755 "$FIX_DIR/omadeck-display-switch" "$BIN"
  ok "Installed $BIN"

  put_lua_block "$AUTOSTART" single-display "o.exec_on_start(\"$BIN\")"
  ok "Starts at login from $AUTOSTART"

  stop_switcher
  if in_hyprland; then
    setsid -f "$BIN" >/dev/null 2>&1
    ok "Running now"
  else
    info "Not inside Hyprland; it will start at your next login"
  fi
}

fix_uninstall() {
  stop_switcher
  remove_lua_block "$AUTOSTART" single-display
  rm -f "$BIN"
  # Bring the Deck screen back if the switcher had turned it off.
  if in_hyprland; then
    hyprctl reload >/dev/null
  fi
  ok "Removed; the Deck screen is back to Hyprland's defaults"
}
