import QtQuick
import qs.Commons
import qs.Ui

// OmaDeck's bar icon: a gamepad that opens the OmaDeck window (Window.qml), or
// brings it to the front when it's already open.
BarWidget {
  id: root
  moduleName: "gladimdim.omadeck"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: String.fromCodePoint(0xF0297)
    tooltipText: "OmaDeck"
    onPressed: function(b) {
      if (root.bar) root.bar.run("omarchy-shell shell summon gladimdim.omadeck '{}'")
    }
  }
}
