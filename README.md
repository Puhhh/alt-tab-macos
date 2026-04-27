# AltTabWindows

A native macOS utility that switches individual windows with `Option + Tab`.

Displays an HUD switcher above all spaces, collects the list of visible windows via `CGWindowList`, and moves focus to the selected window through the Accessibility API.

## Features

- global hotkey `Option + Tab`
- switching between individual windows, not just between applications
- HUD overlay with the window list and current selection
- window activation on releasing `Option`
- cancel switching with `Esc`
- menu bar icon and a permissions status window
- multi-display support — the HUD is positioned on the active screen

## Requirements

- macOS 14.0+
- Swift 5.9+ (Xcode Command Line Tools or full Xcode)
- `System Settings > Privacy & Security > Accessibility` access

No external dependencies.

## Installation

```bash
bash make-app.sh
```

The script builds a release binary, assembles the `.app` bundle, and signs it with an ad-hoc signature. The finished bundle appears in the project root:

```text
AltTabWindows.app
```

Drag `AltTabWindows.app` into `/Applications`.

On first launch macOS may show an unknown developer warning. To bypass it:

```bash
xattr -d com.apple.quarantine /Applications/AltTabWindows.app
```

## Building for Development

```bash
swift build
```

The binary will be located at `.build/debug/AltTabWindows`.

## Permissions

Without Accessibility access the application cannot:

- read window titles and geometry
- determine the currently active window
- move focus to the selected window

If access has not been granted, the main window will show the permission status and a button to open System Settings.

## How to Use

1. Keep `AltTabWindows` running in the background.
2. Hold `Option`.
3. Press `Tab` to move forward through the list of visible windows.
4. Release `Option` — focus will move to the selected window.
5. Press `Esc` to close the HUD without switching.

## How Switching Works

- the list is built from on-screen windows via `CGWindowListCopyWindowInfo`
- system and minimized windows are excluded
- order is based on z-order and a local history of recent switches
- on activation the window is raised and receives focus through the Accessibility API

## Limitations

- only works with windows accessible through public macOS APIs
- switching is unavailable without Accessibility permission
- minimized windows are not included in the list
- the order is not an exact replica of the system MRU in all scenarios

## Project Structure

```
Sources/AltTabWindows/
  App/           — entry point, AppDelegate, AppController, settings window
  HotKey/        — global Option + Tab registration via Carbon API
  Window/        — window collection, models, switching history
  Accessibility/ — reading and activating windows via AX API
  Switcher/      — HUD panel, window cards, screen positioning
```
