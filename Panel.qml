import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.gardensazurescens.astroterm"
  ipcTarget: "io.github.gardensazurescens.astroterm"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string city: String(setting("city", ""))
  readonly property bool useColor: setting("color", false) === true
  readonly property bool useConstellations: setting("constellations", false) === true
  readonly property bool useUnicode: setting("unicode", false) === true
  readonly property bool useGrid: setting("grid", false) === true
  readonly property real speed: Math.max(0.01, Number(setting("speed", 1)) || 1)
  readonly property real aspectRatio: Math.max(0, Number(setting("aspectRatio", 0)) || 0)

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function persist(changes) {
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    for (var changed in changes) entry[changed] = changes[changed]
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function launch() {
    if (root.hostWidget && root.hostWidget.launch) root.hostWidget.launch()
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(390))
    contentHeight: popup.fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "o" || text === "O") root.launch()
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: contentColumn
          width: parent.width
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            title: "Astroterm"
            meta: root.city === "" ? "Default location" : root.city
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "✦"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Button {
            width: parent.width
            text: "Open star map"
            onClicked: root.launch()
          }

          Column {
            width: parent.width
            spacing: Style.space(7)

            PanelSectionHeader {
              text: "LOCATION"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            TextField {
              id: cityField
              width: parent.width
              text: root.city
              placeholderText: "City, e.g. Phoenix"
              foreground: root.foreground
              font.family: root.fontFamily
              onAccepted: root.persist({ city: text.trim() })
            }

            Text {
              width: parent.width
              text: "Leave empty for Astroterm's default coordinates."
              color: Qt.darker(root.foreground, 1.45)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "RENDERING"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            ToggleRow {
              width: parent.width
              label: "Terminal colors"
              checked: root.useColor
              onToggled: root.persist({ color: !root.useColor })
            }
            ToggleRow {
              width: parent.width
              label: "Constellation lines"
              checked: root.useConstellations
              onToggled: root.persist({ constellations: !root.useConstellations })
            }
            ToggleRow {
              width: parent.width
              label: "Unicode characters"
              checked: root.useUnicode
              onToggled: root.persist({ unicode: !root.useUnicode })
            }
            ToggleRow {
              width: parent.width
              label: "Azimuthal grid"
              checked: root.useGrid
              onToggled: root.persist({ grid: !root.useGrid })
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(7)

            PanelSectionHeader {
              text: "ANIMATION"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              spacing: Style.space(7)
              Repeater {
                model: [0.25, 1, 10, 100]
                Button {
                  required property real modelData
                  text: modelData + "x"
                  selected: root.speed === modelData
                  onClicked: root.persist({ speed: modelData })
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(7)

            PanelSectionHeader {
              text: "TERMINAL SHAPE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              spacing: Style.space(7)
              Repeater {
                model: [0, 1, 1.5, 2, 2.5]
                Button {
                  required property real modelData
                  text: modelData === 0 ? "Auto" : modelData + ":1"
                  selected: root.aspectRatio === modelData
                  onClicked: root.persist({ aspectRatio: modelData })
                }
              }
            }
          }
        }
      }
    }
  }

  component ToggleRow: Item {
    property string label: ""
    property bool checked: false
    signal toggled()
    implicitHeight: Math.max(rowLabel.implicitHeight, rowSwitch.implicitHeight)

    Text {
      id: rowLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: parent.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    ToggleSwitch {
      id: rowSwitch
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: parent.checked
      foreground: root.foreground
      onToggled: parent.toggled()
    }
  }
}
