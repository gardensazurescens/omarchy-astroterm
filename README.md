# Astroterm for Omarchy

Adds an Astroterm launcher to the Omarchy bar and application menu.

Astroterm must already be installed. This plugin launches it in the configured
Omarchy terminal, so it works with the user's terminal choice and theme.

## Install

```bash
omarchy plugin validate ~/.config/omarchy/plugins/io.github.gardensazurescens.astroterm
omarchy plugin enable io.github.gardensazurescens.astroterm --section left
mkdir -p ~/.local/share/applications
cp ~/.config/omarchy/plugins/io.github.gardensazurescens.astroterm/astroterm.desktop ~/.local/share/applications/
omarchy-shell shell rescanPlugins
```

The menu entry is added by copying `omarchy-menu.jsonc` from this repository to
`~/.config/omarchy/extensions/omarchy-menu.jsonc`. Left-click the bar widget to
open its settings panel; right-click launches the current view immediately.

## Configure

The widget uses Astroterm's command-line options. For example:

```bash
omarchy bar set io.github.gardensazurescens.astroterm city "Phoenix" --json
omarchy bar set io.github.gardensazurescens.astroterm color true --json
omarchy bar set io.github.gardensazurescens.astroterm constellations true --json
omarchy bar set io.github.gardensazurescens.astroterm unicode true --json
omarchy bar set io.github.gardensazurescens.astroterm grid false --json
omarchy bar set io.github.gardensazurescens.astroterm speed 1 --json
omarchy bar set io.github.gardensazurescens.astroterm aspectRatio 0 --json
```

Click the star in the bar to open the configured view. The application menu and
desktop entry launch Astroterm with its normal defaults. Use the popup settings
to opt into colors, constellation lines, Unicode, a grid, or a manual terminal
aspect ratio.

Remove it with:

```bash
omarchy plugin remove io.github.gardensazurescens.astroterm
rm -f ~/.local/share/applications/astroterm.desktop
```
