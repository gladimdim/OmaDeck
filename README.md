# OmaDeck

**Fixes and tweaks that make [Omarchy](https://omarchy.org/) great on the Steam Deck.**

Omarchy works on the Steam Deck, but a few things feel like a laptop rather than a handheld you dock to a big screen. OmaDeck fixes them with one copy-paste command. Every fix stays inside your own `~/.config` and can be removed again.

## Install

Open a terminal on your Deck (in Omarchy's desktop session) and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/gladimdim/OmaDeck/main/install.sh | bash
```

You don't need to log out: fixes take effect right away. Run the same command again any time to update OmaDeck and pick up new fixes. Running it more than once is safe.

## Fixes

### 🖥️ Single display

Works like Windows' *"Show only on 2"*: you use one screen at a time.

| You do this | OmaDeck does this |
| --- | --- |
| Plug in a monitor or TV | The Deck screen turns off and the external display gets all your windows and workspaces |
| Unplug it | The Deck screen turns back on, with the rotation and scale from your own `monitors.lua` |

A small listener (`~/.local/bin/omadeck-display-switch`) watches Hyprland's monitor events. It starts at login from `~/.config/hypr/autostart.lua`. It doesn't hard-code anything about your panel: to turn the Deck screen back on, it reloads your Hyprland config. Gaming Mode is unaffected.

*More fixes coming.*

## Uninstall

```bash
~/.local/share/omadeck/install.sh --uninstall
```

This removes every fix, removes OmaDeck's lines from your config, and turns the Deck screen back on. To remove the downloaded copy too, delete `~/.local/share/omadeck`.

## Options

```text
install.sh [--uninstall] [--force] [--list]

  --uninstall  Remove every OmaDeck fix and restore the defaults
  --force      Run on hardware that is not a Steam Deck
  --list       Show the available fixes and exit
```

## Requirements

- A Steam Deck, LCD or OLED. The installer checks for this and refuses to run on anything else unless you pass `--force`.
- Omarchy with Hyprland's Lua config (Hyprland 0.55 or newer, `~/.config/hypr/hyprland.lua`).
- `git`, `socat` and `jq`. Omarchy ships all three, and the installer adds `socat` or `jq` if either is missing.

## What it changes

OmaDeck only touches your user account. It never edits `/usr/share/omarchy`, so `omarchy update` can't undo it.

| Path | Purpose |
| --- | --- |
| `~/.local/share/omadeck/` | The downloaded copy of this repo |
| `~/.local/bin/omadeck-*` | Helper scripts installed by fixes |
| `~/.config/hypr/*.lua` | Small blocks between `-- >>> omadeck: <fix> >>>` markers |

Re-running the installer replaces those marked blocks instead of adding copies, and uninstalling removes them.

## Adding a fix

Each fix is a folder in `fixes/` with a `fix.sh` that `install.sh` sources:

```bash
FIX_NAME="My fix"
FIX_DESCRIPTION="One line about what it does."

fix_install() {
  # Idempotent: running it twice must give the same result as running it once.
  put_lua_block "$HOME/.config/hypr/looknfeel.lua" my-fix 'hl.config({ ... })'
  ok "Done"
}

fix_uninstall() {
  remove_lua_block "$HOME/.config/hypr/looknfeel.lua" my-fix
}
```

Fixes run in alphabetical order, each in its own subshell with `set -e`. Inside `fix.sh` you can use:

- `$FIX_DIR`: the fix's folder
- `info`, `ok`, `warn`: output helpers
- `put_lua_block`, `remove_lua_block`: add or remove a marked config block
- `in_hyprland`: true when a Hyprland session is running

To test your changes, run `./install.sh` from your clone. It uses the clone directly and doesn't download anything.
