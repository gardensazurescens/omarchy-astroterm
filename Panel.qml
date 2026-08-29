import QtQuick
import QtQuick.Controls
import Quickshell.Io
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
  readonly property string locationLabel: root.city !== "" ? root.city : "Default location"
  readonly property bool useColor: setting("color", false) === true
  readonly property bool useConstellations: setting("constellations", false) === true
  readonly property bool useUnicode: setting("unicode", false) === true
  readonly property bool useGrid: setting("grid", false) === true
  readonly property real speed: Math.max(0.01, Number(setting("speed", 1)) || 1)
  readonly property real aspectRatio: Math.max(0, Number(setting("aspectRatio", 0)) || 0)

  property bool editingLocation: false
  property bool savingLocation: false
  property var locationSuggestions: []
  property int suggestionIndex: 0
  property string geocodePendingQuery: ""
  property string geocodeActiveQuery: ""

  function open() { root.controller.show() }
  function close() {
    if (root.editingLocation) root.cancelEditingLocation()
    root.controller.hide()
  }
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

  // ---- Location editing. Mirrors the weather panel: clicking the location
  //      label swaps it for a search field, picking a geocoded suggestion
  //      persists name + coordinates to the widget's shell.json entry, and an
  //      empty commit returns to Astroterm's default coordinates.
  function startEditingLocation() {
    editingLocation = true
    savingLocation = false
    locationSuggestions = []
    suggestionIndex = 0
    Qt.callLater(function() {
      locationField.text = root.city
      locationField.selectAll()
      locationField.forceActiveFocus()
    })
  }

  function cancelEditingLocation() {
    editingLocation = false
    savingLocation = false
    locationSuggestions = []
    geocodeDebounce.stop()
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function commitLocation() {
    var name = String(locationField.text || "").trim()
    if (name === "") {
      clearLocation()
      return
    }
    var suggestion = locationSuggestions[Math.max(0, Math.min(suggestionIndex, locationSuggestions.length - 1))]
    if (suggestion) {
      persist({ city: suggestion.name, latitude: suggestion.latitude, longitude: suggestion.longitude })
    } else {
      persist({ city: name, latitude: null, longitude: null })
    }
    cancelEditingLocation()
  }

  function pickSuggestion(suggestion) {
    if (!suggestion) return
    persist({ city: suggestion.name, latitude: suggestion.latitude, longitude: suggestion.longitude })
    cancelEditingLocation()
  }

  function clearLocation() {
    persist({ city: "", latitude: null, longitude: null })
    cancelEditingLocation()
  }

  function parseGeocodingResults(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      var results = data.results
      if (!results || !results.length) return []
      var out = []
      for (var i = 0; i < results.length; i++) {
        var r = results[i]
        if (!r || !r.name || r.latitude === undefined || r.longitude === undefined) continue
        var region = [r.admin1, r.country].filter(function(part) { return !!part }).join(", ")
        out.push({ name: String(r.name), description: region, latitude: r.latitude, longitude: r.longitude })
      }
      return out
    } catch (e) {
      return []
    }
  }

  function requestGeocode() {
    var query = locationField.text.trim()
    if (query.length < 2) {
      locationSuggestions = []
      return
    }
    geocodePendingQuery = query
    if (!geocodeProc.running) startGeocode()
  }

  function startGeocode() {
    geocodeActiveQuery = geocodePendingQuery
    geocodeProc.command = ["curl", "-fsS", "--max-time", "5",
      "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(geocodeActiveQuery) + "&count=5&language=en&format=json"]
    geocodeProc.running = true
  }

  Process {
    id: geocodeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.locationSuggestions = root.editingLocation ? root.parseGeocodingResults(text) : []
        root.suggestionIndex = 0
        if (root.geocodePendingQuery !== root.geocodeActiveQuery) Qt.callLater(root.startGeocode)
      }
    }
  }

  Timer {
    id: geocodeDebounce
    interval: 300
    onTriggered: root.requestGeocode()
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
      blocked: root.editingLocation
      onCloseRequested: root.close()
      onReturnRequested: root.startEditingLocation()
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
            meta: root.locationLabel
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
            id: locationSection
            width: parent.width
            spacing: Style.space(7)

            PanelSectionHeader {
              text: "LOCATION"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              visible: !root.editingLocation
              spacing: Style.space(6)

              TapHandler {
                onTapped: root.startEditingLocation()
              }
              HoverHandler {
                cursorShape: Qt.PointingHandCursor
              }

              Text {
                text: ""
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: root.locationLabel.toUpperCase()
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Row {
              visible: root.editingLocation
              spacing: Style.space(6)

              TextField {
                id: locationField
                width: locationSection.width - clearLocationBox.width - Style.space(6)
                enabled: !root.savingLocation
                placeholderText: "Search city"
                foreground: root.foreground
                font.family: root.fontFamily

                onTextChanged: if (root.editingLocation && !root.savingLocation) geocodeDebounce.restart()

                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Escape) {
                    root.cancelEditingLocation()
                    event.accepted = true
                  } else if (event.key === Qt.Key_Down) {
                    if (root.suggestionIndex < root.locationSuggestions.length - 1) root.suggestionIndex++
                    event.accepted = true
                  } else if (event.key === Qt.Key_Up) {
                    if (root.suggestionIndex > 0) root.suggestionIndex--
                    event.accepted = true
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.commitLocation()
                    event.accepted = true
                  }
                }
              }

              Rectangle {
                id: clearLocationBox
                width: Style.space(18)
                height: Style.space(18)
                anchors.verticalCenter: parent.verticalCenter
                radius: Math.min(4, Style.cornerRadius)
                color: clearLocationArea.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: "✕"
                  font.family: root.fontFamily
                  color: Qt.darker(root.foreground, 1.4)
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  id: clearLocationArea
                  anchors.fill: parent
                  enabled: !root.savingLocation
                  hoverEnabled: true
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: root.clearLocation()
                }
              }
            }

            Column {
              visible: root.editingLocation && !root.savingLocation && root.locationSuggestions.length > 0
              width: parent.width
              spacing: 0

              Repeater {
                model: root.locationSuggestions

                Rectangle {
                  required property var modelData
                  required property int index
                  width: parent.width
                  height: suggestionRow.implicitHeight + Style.space(12)
                  radius: Style.cornerRadius
                  color: index === root.suggestionIndex ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"

                  Row {
                    id: suggestionRow
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(16)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    Text {
                      text: modelData.name
                      color: index === root.suggestionIndex ? Style.hoverStateColor(root.foreground, Color.accent) : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }
                    Text {
                      visible: text !== ""
                      text: modelData.description
                      color: Qt.darker(root.foreground, 1.5)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: root.suggestionIndex = index
                    onClicked: root.pickSuggestion(modelData)
                  }
                }
              }
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
