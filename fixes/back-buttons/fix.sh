# Sourced by bin/omadeck, which provides FIX_DIR and the info/ok/warn,
# put_lua_block/remove_lua_block/has_lua_block and in_hyprland helpers.

FIX_NAME="Back buttons scroll"
FIX_CATEGORY="Input"
FIX_DESCRIPTION="The four back buttons scroll like a mouse wheel: L4 and R4 up, L5 and R5 down."

BIN="$HOME/.local/bin/omadeck-back-scroll"
AUTOSTART="$HOME/.config/hypr/autostart.lua"
LIZARD_MODE=/sys/module/hid_steam/parameters/lizard_mode

stop_scroller() {
  pkill -f "$BIN" 2>/dev/null || true
  for _ in {1..20}; do
    pgrep -f "$BIN" >/dev/null || return 0
    sleep 0.1
  done
}

fix_status() {
  [[ -x $BIN ]] && has_lua_block "$AUTOSTART" back-buttons
}

fix_install() {
  command -v python3 >/dev/null || omarchy pkg add python

  # steam-devices lets your user read the controller's hidraw node and create
  # the virtual wheel through /dev/uinput.
  if ! pacman -Q steam-devices >/dev/null 2>&1; then
    info "Installing steam-devices (controller access for your user)"
    omarchy pkg add steam-devices
    # Apply the new rules to devices that are already plugged in.
    sudo udevadm trigger --action=change --subsystem-match=hidraw --subsystem-match=misc || true
    sudo udevadm trigger --action=change --subsystem-match=input --property-match=ID_VENDOR_ID=28de || true
  fi

  install -Dm755 "$FIX_DIR/omadeck-back-scroll" "$BIN"
  ok "Installed $BIN"

  put_lua_block "$AUTOSTART" back-buttons "o.exec_on_start(\"$BIN\")"
  ok "Starts at login from $AUTOSTART"

  if [[ $(cat "$LIZARD_MODE" 2>/dev/null) == N ]]; then
    warn "hid_steam's lizard_mode is off on this Deck, so another program drives the controller."
    warn "The back buttons will scroll once lizard_mode is back on (the kernel default)."
  fi

  stop_scroller
  if in_hyprland; then
    setsid -f "$BIN" >/dev/null 2>&1
    ok "Running now. While Steam is open, Steam's own controller layout applies."
  else
    info "Not inside Hyprland; it will start at your next login"
  fi
}

fix_uninstall() {
  stop_scroller
  remove_lua_block "$AUTOSTART" back-buttons
  rm -f "$BIN"
  ok "Off; the back buttons do nothing outside Steam again"
}
