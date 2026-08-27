import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.gardensazurescens.astroterm"

  readonly property string city: String(setting("city", ""))
  readonly property bool color: setting("color", false) === true
  readonly property bool constellations: setting("constellations", false) === true
  readonly property bool unicode: setting("unicode", false) === true
  readonly property bool grid: setting("grid", false) === true
  readonly property real speed: Math.max(0.01, Number(setting("speed", 1)) || 1)
  readonly property real aspectRatio: Math.max(0, Number(setting("aspectRatio", 0)) || 0)

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function launch() {
    var args = ["astroterm"]
    if (city.trim() !== "") args.push("--city", shellQuote(city.trim()))
    if (color) args.push("--color")
    if (constellations) args.push("--constellations")
    if (unicode) args.push("--unicode")
    if (grid) args.push("--grid")
    if (speed !== 1) args.push("--speed", String(speed))
    if (aspectRatio > 0) args.push("--aspect-ratio", String(aspectRatio))
    if (root.bar) root.bar.run("omarchy-launch-terminal " + args.join(" "))
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "✦"
    slotSize: Style.bar.statusSlot
    tooltipText: "Open Astroterm"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.launch()
      else root.togglePanel()
    }
  }

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

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
}
