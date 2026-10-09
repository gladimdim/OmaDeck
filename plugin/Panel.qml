import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// OmaDeck bar widget: a gamepad icon that opens a panel listing every OmaDeck
// fix, grouped by category, each with an on/off toggle. All state lives in the
// `omadeck` command; this panel only reads `omadeck list --json` and runs
// `omadeck enable|disable <id>`.
Panel {
  id: root
  moduleName: "gladimdim.omadeck"
  ipcTarget: "gladimdim.omadeck"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
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

  function moveCursor(delta) {
    if (fixes.length === 0) return
    cursorIndex = (cursorIndex + delta + fixes.length) % fixes.length
  }

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      actionError = ""
      refresh()
    }
  }

  Process {
    id: listProc
    command: ["bash", "-c", "exec \"$0\" list --json 2>&1", root.cli]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseList(text) }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.finishAction(text) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.gamepadIcon
    tooltipText: "OmaDeck"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dy !== 0 ? dy : dx)
      }
      onActivateRequested: {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.toggleFix(root.fixes[root.cursorIndex])
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
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
