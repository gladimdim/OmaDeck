import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// OmaDeck's window: every OmaDeck fix, grouped by category, each with an
// on/off toggle, and the companion apps below. A real window rather than a bar
// popup; the bar icon (BarWidget.qml) summons it, and so does
//   omarchy-shell shell summon gladimdim.omadeck '{}'
// All state lives in the `omadeck` command; this window only reads
// `omadeck list --json` and runs `omadeck enable|disable <id>`.
Item {
  id: root

  readonly property string pluginId: "gladimdim.omadeck"
  readonly property string windowTitle: "OmaDeck"

  // Injected by the shell when the panel loads.
  property var shell: null

  // The shell reads this to decide whether `toggle` opens or hides.
  readonly property bool opened: window.visible
  property bool closingFromHost: false

  readonly property color foreground: Color.foreground
  readonly property string fontFamily: Style.font.family
  readonly property string cli: Quickshell.env("HOME") + "/.local/bin/omadeck"

  readonly property string gamepadIcon: String.fromCodePoint(0xF0297)
  readonly property var categoryIcons: ({
    "Hardware": String.fromCodePoint(0xF061A),
    "Display": String.fromCodePoint(0xF0379),
    "Input": String.fromCodePoint(0xF030C),
    "Power": String.fromCodePoint(0xF0079),
    "Audio": String.fromCodePoint(0xF04C3),
    "Appearance": String.fromCodePoint(0xF03D8)
  })

  // Apps that go well with OmaDeck. Not tweaks: each gets links, no toggle.
  // An app whose Omarchy plugin is already installed shows a tick instead.
  readonly property string companionsIcon: String.fromCodePoint(0xF003B)
  readonly property string installedIcon: String.fromCodePoint(0xF05E0)
  readonly property string pluginsDir: Quickshell.env("HOME") + "/.config/omarchy/plugins"
  readonly property var companions: [
    {
      name: "Omakey",
      pluginId: "gladimdim.omakey",
      description: "Your phone as a real keyboard and touchpad for the Deck: Super, Esc, F-keys and chords, over Wi-Fi or Bluetooth.",
      links: [
        { label: "Omarchy plugin", icon: String.fromCodePoint(0xF0431), url: "https://github.com/gladimdim/omakey-omarchy-plugin" },
        { label: "Android app", icon: String.fromCodePoint(0xF0032), url: "https://github.com/gladimdim/omakey-mobile/releases/latest" }
      ]
    }
  ]

  // pluginId -> true for each companion whose plugin is installed.
  property var installedCompanions: ({})

  property var fixes: []
  property bool loaded: false
  property string loadError: ""
  property string actionError: ""

  // The fix being switched right now and the state it is being switched to.
  // Rows show that state at once instead of waiting for the command.
  property string pendingId: ""
  property bool pendingState: false

  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property int enabledCount: fixes.filter(function(f) { return f.enabled }).length

  // [{ name, icon, fixes: [fix + flatIndex] }] in the order categories first appear.
  readonly property var categories: {
    var order = []
    var byName = {}
    for (var i = 0; i < fixes.length; i++) {
      var fix = Object.assign({ flatIndex: i }, fixes[i])
      if (!byName[fix.category]) {
        byName[fix.category] = { name: fix.category, icon: categoryIcon(fix.category), fixes: [] }
        order.push(byName[fix.category])
      }
      byName[fix.category].fixes.push(fix)
    }
    return order
  }

  function categoryIcon(name) {
    return categoryIcons[name] || String.fromCodePoint(0xF0493)
  }

  function isOn(fix) {
    return pendingId === fix.id ? pendingState : fix.enabled
  }

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function parseList(raw) {
    try {
      var parsed = JSON.parse(raw)
      if (!Array.isArray(parsed)) throw new Error("not a list")
      fixes = parsed
      loadError = ""
    } catch (e) {
      loadError = raw.indexOf("No such file") >= 0
        ? "The omadeck command is missing. Re-run the OmaDeck installer."
        : "Couldn't read OmaDeck's fixes: " + raw.trim().split("\n").pop()
    }
    loaded = true
    if (cursorIndex >= fixes.length) cursorIndex = Math.max(0, fixes.length - 1)
  }

  function toggleFix(fix) {
    if (!fix || actionProc.running) return
    actionError = ""
    pendingId = fix.id
    pendingState = !fix.enabled
    actionProc.command = ["bash", "-c", "\"$0\" \"$@\" 2>&1; echo \"::exit=$?\"", cli, pendingState ? "enable" : "disable", fix.id]
    actionProc.running = true
  }

  function finishAction(raw) {
    var match = raw.match(/::exit=(\d+)\s*$/)
    var code = match ? parseInt(match[1]) : 1
    if (code !== 0) {
      var lines = raw.replace(/::exit=\d+\s*$/, "").trim().split("\n")
      actionError = "Couldn't switch it: " + (lines.pop() || "unknown error")
    }
    pendingId = ""
    refresh()
  }

  function refreshCompanions() {
    if (companionsProc.running) return
    companionsProc.command = ["bash", "-c", "for id; do [[ -f $0/$id/manifest.json ]] && echo \"$id\"; done; true", pluginsDir]
      .concat(companions.map(function(c) { return c.pluginId }))
    companionsProc.running = true
  }

  function parseCompanions(raw) {
    var installed = {}
    raw.trim().split("\n").forEach(function(id) { if (id) installed[id] = true })
    installedCompanions = installed
  }

  function openLink(url) {
    Quickshell.execDetached(["xdg-open", url])
  }

  function moveCursor(delta) {
    if (fixes.length === 0) return
    cursorIndex = (cursorIndex + delta + fixes.length) % fixes.length
  }

  // Called by the shell on every summon. A second summon brings an open
  // window to the front and back to the middle of the screen, instead of
  // opening another one: a floating window left behind by a monitor change
  // can sit entirely off-screen, and then the icon would seem to do nothing.
  function open(payloadJson) {
    closingFromHost = false
    if (window.visible) {
      Quickshell.execDetached(["bash", "-c", "hyprctl dispatch \"$0\" >/dev/null && hyprctl dispatch 'hl.dsp.window.center()' >/dev/null",
        "hl.dsp.focus({ window = \"title:^" + windowTitle + "$\" })"])
    } else {
      cursorActive = false
      actionError = ""
      window.visible = true
    }
    refresh()
    refreshCompanions()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // The shell hiding us (`shell hide`, or `toggle` while open). It already
  // knows, so don't tell it back.
  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  // The user closing the window (Esc, or the compositor's close). Tell the
  // shell, so its open state stays right and the next summon opens us again.
  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else window.visible = false
  }

  Process {
    id: listProc
    command: ["bash", "-c", "exec \"$0\" list --json 2>&1", root.cli]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseList(text) }
  }

  Process {
    id: companionsProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseCompanions(text) }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.finishAction(text) }
  }

  // Hyprland floats and centers this window at a fixed size through the rule
  // `omadeck setup` adds to ~/.config/hypr/looknfeel.lua.
  FloatingWindow {
    id: window
    title: root.windowTitle
    color: Color.background
    implicitWidth: 520
    implicitHeight: 720
    minimumSize: Qt.size(420, 480)

    onVisibleChanged: {
      if (!visible && !root.closingFromHost) root.requestClose()
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dy !== 0 ? dy : dx)
      }
      onActivateRequested: {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.toggleFix(root.fixes[root.cursorIndex])
      }
      onCloseRequested: root.requestClose()

      ScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: Style.space(24)
        contentWidth: availableWidth
        clip: true

        Column {
          id: column
          width: scroll.availableWidth
          spacing: Style.space(14)

          PanelHero {
            title: "OmaDeck"
            meta: !root.loaded ? "Loading"
              : root.loadError !== "" ? "Not available"
              : root.enabledCount + " of " + root.fixes.length + (root.fixes.length === 1 ? " tweak on" : " tweaks on")
            detail: "Steam Deck"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Text {
              textFormat: Text.PlainText
              text: root.gamepadIcon
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }

          Text {
            visible: text !== ""
            text: root.loadError !== "" ? root.loadError : root.actionError
            width: parent.width
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Repeater {
            model: root.categories

            Column {
              id: category
              required property var modelData
              width: column.width
              spacing: Style.space(10)

              PanelSeparator { foreground: root.foreground }

              PanelSectionHeader {
                text: category.modelData.icon + "  " + category.modelData.name.toUpperCase()
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Repeater {
                model: category.modelData.fixes

                Toggle {
                  required property var modelData
                  width: category.width
                  label: modelData.name
                  description: modelData.description
                  checked: root.isOn(modelData)
                  opacity: root.pendingId === modelData.id ? 0.7 : 1
                  hasCursor: root.cursorActive && root.cursorIndex === modelData.flatIndex
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.toggleFix(modelData)
                  onHovered: function(h) {
                    if (h) {
                      root.cursorActive = true
                      root.cursorIndex = modelData.flatIndex
                    }
                  }
                }
              }
            }
          }

          // ---- companion apps ----
          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: root.companionsIcon + "  COMPANION APPS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: root.companions

            Column {
              id: companion
              required property var modelData
              readonly property bool installed: !!root.installedCompanions[modelData.pluginId]
              width: column.width
              spacing: Style.space(6)

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: companion.modelData.name
                  textFormat: Text.PlainText
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  visible: companion.installed
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.installedIcon + " Installed"
                  textFormat: Text.PlainText
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                width: parent.width
                text: companion.modelData.description
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Row {
                id: companionLinks
                visible: !companion.installed
                width: parent.width
                spacing: Style.space(6)
                readonly property real cellWidth: (width - spacing * (companion.modelData.links.length - 1)) / companion.modelData.links.length

                Repeater {
                  model: companion.modelData.links

                  Button {
                    required property var modelData
                    width: companionLinks.cellWidth
                    text: modelData.label
                    iconText: modelData.icon
                    tooltipText: modelData.url
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    bordered: true
                    onClicked: root.openLink(modelData.url)
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Text {
            width: parent.width
            text: "Also from a terminal: omadeck list"
            textFormat: Text.PlainText
            color: Qt.darker(root.foreground, 1.6)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
