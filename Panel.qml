import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "sshuttle.tunnel"
  ipcTarget: "sshuttle.tunnel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property string logText: ""
  property bool logLoading: false

  property string cfgHost: ""
  property string cfgUser: ""
  property var cfgSubnets: []
  property string newSubnet: ""

  readonly property string tunnelState: hostWidget ? hostWidget.tunnelState : "stopped"
  readonly property bool busy: hostWidget ? hostWidget.busy : false
  readonly property string statusDetail: hostWidget ? String(hostWidget.statusDetail) : ""

  readonly property color stateColor: tunnelState === "running" ? "#4caf50"
      : (tunnelState === "stopped" ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.4) : "#ffb74d")

  function open() {
    root.controller.show()
    refresh()
  }

  function close() { root.controller.hide() }
  function toggle() { root.opened ? close() : open() }
  function openFromHotkey() { open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function closeForPopoutSwitch() {
    root.popoutSwitchClosing = true
    close()
    Qt.callLater(function() { root.popoutSwitchClosing = false })
  }

  function refresh() {
    loadLog()
    loadConfig()
  }

  readonly property string script: Qt.resolvedUrl("shuttle").toString().replace("file://", "")

  function loadConfig() {
    if (!configProc.running) configProc.running = true
  }

  function runCfg(args) {
    cfgProc.command = [root.script].concat(args)
    cfgProc.running = true
  }

  function addSubnet(text) {
    var v = String(text || "").trim()
    if (v === "") return
    root.newSubnet = ""
    root.runCfg(["subnet", "add", v])
  }

  function applyConfig(raw) {
    var host = "", user = "", subnets = []
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line.indexOf("host=") === 0) host = line.substring(5)
      else if (line.indexOf("user=") === 0) user = line.substring(5)
      else if (line.indexOf("subnet=") === 0) subnets.push(line.substring(7))
    }
    root.cfgHost = host
    root.cfgUser = user
    root.cfgSubnets = subnets
  }

  Process {
    id: configProc
    command: [root.script, "config"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyConfig(text) }
  }

  Process {
    id: cfgProc
    onExited: root.loadConfig()
  }

  function loadLog() {
    if (!logProc.running) {
      logLoading = true
      logProc.running = true
    }
  }

  function start() { if (hostWidget && hostWidget.start) hostWidget.start() }
  function stop() { if (hostWidget && hostWidget.stop) hostWidget.stop() }

  Process {
    id: logProc
    command: [root.script, "logs"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.logText = text.trim() || "(no log output yet)"
        root.logLoading = false
      }
    }
    onExited: root.logLoading = false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(10)

          Column {
            width: parent.width - Style.space(90)
            spacing: Style.space(2)

            Text {
              text: "sshuttle tunnel"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              renderType: Text.NativeRendering
            }

            Text {
              width: parent.width
              text: (root.cfgSubnets.length ? root.cfgSubnets.join(", ") : "no subnets")
                    + " via " + root.cfgHost
              color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.6)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              renderType: Text.NativeRendering
            }
          }

          Rectangle {
            width: pill.implicitWidth + Style.space(16)
            height: Style.space(26)
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.16)
            border.width: 1
            border.color: root.stateColor

            Row {
              id: pill
              anchors.centerIn: parent
              spacing: Style.space(6)

              Rectangle {
                width: 8
                height: 8
                radius: 4
                color: root.stateColor
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: root.tunnelState
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Repeater {
            model: [
              { key: "start", label: "\uf04b  start", enabled: root.tunnelState === "stopped" && !root.busy },
              { key: "stop", label: "\uf04d  stop", enabled: root.tunnelState === "running" && !root.busy }
            ]

            Rectangle {
              required property var modelData
              width: (content.width - Style.space(8)) / 2
              height: Style.space(34)
              radius: Style.cornerRadius
              color: modelData.enabled && actionArea.containsMouse
                  ? Color.accent : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.08)
              border.width: 1
              border.color: modelData.enabled ? Color.accent : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.15)
              opacity: modelData.enabled ? 1.0 : 0.45

              Text {
                anchors.centerIn: parent
                text: modelData.label
                color: modelData.enabled && actionArea.containsMouse ? Color.background : root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                renderType: Text.NativeRendering
              }

              MouseArea {
                id: actionArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: modelData.enabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: modelData.key === "start" ? root.start() : root.stop()
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          Text {
            text: "tunnel config"
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.7)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Repeater {
            model: [
              { key: "host", label: "host", value: root.cfgHost },
              { key: "user", label: "user", value: root.cfgUser }
            ]

            Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(8)

              Text {
                width: Style.space(40)
                text: modelData.label
                color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.6)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }

              Rectangle {
                width: parent.width - Style.space(48)
                height: Style.space(26)
                radius: 6
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(0, 0, 0, 0.25)
                border.width: 1
                border.color: cfgInput.activeFocus ? Color.accent
                    : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.2)

                TextInput {
                  id: cfgInput
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  verticalAlignment: TextInput.AlignVCenter
                  text: modelData.value
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  clip: true
                  selectByMouse: true
                  onEditingFinished: {
                    var v = text.trim()
                    if (v !== "" && v !== modelData.value)
                      root.runCfg(["set", modelData.key, v])
                  }
                }
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
              text: "subnets"
              color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.6)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              visible: root.tunnelState === "running"
              text: "restart to apply"
              color: "#ffb74d"
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Repeater {
            model: root.cfgSubnets

            Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width - Style.space(26)
                text: "\uf10c  " + modelData
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Rectangle {
                width: Style.space(20)
                height: Style.space(20)
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: delArea.containsMouse ? Qt.rgba(1, 0.4, 0.4, 0.25) : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: "\uf00d"
                  color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.7)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  id: delArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.runCfg(["subnet", "del", modelData])
                }
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Rectangle {
              width: parent.width - Style.space(34)
              height: Style.space(26)
              radius: 6
              color: Qt.rgba(0, 0, 0, 0.25)
              border.width: 1
              border.color: newSubnetInput.activeFocus ? Color.accent
                  : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.2)

              TextInput {
                id: newSubnetInput
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                verticalAlignment: TextInput.AlignVCenter
                text: root.newSubnet
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                clip: true
                selectByMouse: true
                onEditingFinished: root.addSubnet(text)
              }

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                visible: newSubnetInput.text === ""
                text: "add subnet, e.g. 10.0.0.0/24"
                color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.35)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }

            Rectangle {
              width: Style.space(28)
              height: Style.space(26)
              radius: 6
              color: addArea.containsMouse ? Color.accent : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.08)
              border.width: 1
              border.color: Color.accent

              Text {
                anchors.centerIn: parent
                text: "\uf067"
                color: addArea.containsMouse ? Color.background : Color.accent
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: addArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.addSubnet(newSubnetInput.text)
              }
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "log"
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.7)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: root.logLoading ? "󰦖" : "\uf021"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter

            RotationAnimator on rotation {
              running: root.logLoading
              from: 0; to: 360
              duration: 800
              loops: Animation.Infinite
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.loadLog()
            }
          }

          Text {
            width: parent.width - Style.space(70)
            text: root.statusDetail
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Rectangle {
          width: parent.width
          height: logScroll.contentHeight + Style.space(16)
          visible: height > Style.space(16)
          radius: Style.cornerRadius
          color: Qt.rgba(0, 0, 0, 0.22)

          Flickable {
            id: logScroll
            width: parent.width - Style.space(16)
            height: parent.height - Style.space(16)
            x: Style.space(8)
            y: Style.space(8)
            contentWidth: width
            contentHeight: logText.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Text {
              id: logText
              width: parent.width
              text: root.logText
              color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.8)
              font.family: "monospace"
              font.pixelSize: 10
              wrapMode: Text.WrapAnywhere
            }
          }
        }
      }
    }
  }
}
