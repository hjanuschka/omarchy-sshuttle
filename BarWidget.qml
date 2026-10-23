import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "sshuttle.tunnel"

  readonly property string script: Qt.resolvedUrl("shuttle").toString().replace("file://", "")

  // "running" | "stopped" | "starting" | "stopping"
  property string tunnelState: "stopped"
  property string statusDetail: ""
  property bool busy: false

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  readonly property color stateColor: tunnelState === "running" ? "#4caf50"
      : (tunnelState === "stopped" ? Qt.rgba(1, 1, 1, 0.35) : "#ffb74d")

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function applyStatus(raw) {
    var text = String(raw || "").trim()
    statusDetail = text
    if (busy) return // action in flight; keep transitional state
    tunnelState = text.indexOf("running") === 0 && text.indexOf("not running") !== 0
        ? "running" : "stopped"
  }

  function start() {
    if (tunnelState === "running" || busy) return
    busy = true
    tunnelState = "starting"
    actionProc.command = ["sudo", root.script, "start"]
    actionProc.running = true
  }

  function stop() {
    if (tunnelState === "stopped" || busy) return
    busy = true
    tunnelState = "stopping"
    actionProc.command = ["sudo", root.script, "stop"]
    actionProc.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  Component.onCompleted: refresh()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Timer {
    interval: 4000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: [root.script, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.statusDetail = text.trim()
    }
    onExited: {
      root.busy = false
      root.refresh()
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.bar && root.bar.vertical ? Style.bar.statusSlot : 46
    fixedHeight: root.bar ? root.bar.barSize : 26
    tooltipText: "sshuttle: " + root.statusDetail

    onPressed: function(b) {
      if (b === Qt.RightButton || b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }

    Row {
      anchors.centerIn: parent
      spacing: 5

      Text {
        text: "\uf0c3" // network/tunnel
        color: root.tunnelState === "running" ? Color.accent : button.foreground
        opacity: root.busy ? 0.5 : 1.0
        font.family: button.fontFamily
        font.pixelSize: 14
        anchors.verticalCenter: parent.verticalCenter
        renderType: Text.NativeRendering
      }

      Rectangle {
        width: 8
        height: 8
        radius: 4
        color: root.stateColor
        anchors.verticalCenter: parent.verticalCenter

        SequentialAnimation on opacity {
          running: root.busy
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 0.25; duration: 400 }
          NumberAnimation { from: 0.25; to: 1.0; duration: 400 }
        }
      }
    }
  }
}
