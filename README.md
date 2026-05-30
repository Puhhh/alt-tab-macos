# AltTabWindows

A native macOS utility that switches individual windows with `Option + Tab`.

Displays an HUD switcher above all spaces, collects the list of visible windows via `CGWindowList`, and moves focus to the selected window through the Accessibility API.

> This is an unsigned open-source utility. It requires Accessibility permission because macOS exposes window inspection and focusing through the Accessibility API.

## Features

- Global hotkey: `Option + Tab`
- Switches between individual windows, not just applications
- HUD overlay with the window list and current selection
- Activates the selected window when `Option` is released
- Cancels switching with `Esc`
- Menu bar icon and a permissions status window
- Multi-display support: the HUD is positioned on the active screen

## Requirements

- macOS 14.0+
- Swift 5.9+ (Xcode Command Line Tools or full Xcode)
- `System Settings > Privacy & Security > Accessibility` access

No external dependencies.

## Install from GitHub Release

1. Download `AltTabWindows.app.zip` from the latest release.
2. Unzip it and move `AltTabWindows.app` to `/Applications`.
3. Launch the app and grant Accessibility access when prompted.

If macOS reports that the app is from an unidentified developer, remove the quarantine attribute after moving it to `/Applications`:

```bash
xattr -d com.apple.quarantine /Applications/AltTabWindows.app
```

## Build from Source

```bash
bash make-app.sh
```

The script builds a release binary, assembles the `.app` bundle, and signs it with an ad-hoc signature. The finished bundle appears in the project root:

```text
AltTabWindows.app
```

Drag `AltTabWindows.app` into `/Applications`.

## Building for Development

```bash
swift build
```

The binary will be located at `.build/debug/AltTabWindows`.

You can also open `AltTabWindows.xcodeproj`, but Swift Package Manager is the primary build path.

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

- The list is built from on-screen windows via `CGWindowListCopyWindowInfo`
- System and minimized windows are excluded
- Order is based on z-order and a local history of recent switches
- On activation the window is raised and receives focus through the Accessibility API

## Limitations

- Only works with windows accessible through public macOS APIs
- Switching is unavailable without Accessibility permission
- Minimized windows are not included in the list
- The order is not an exact replica of the system MRU in all scenarios

## Release Checklist

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `make-app.sh`.
2. Run `bash make-app.sh`.
3. Test `/Applications/AltTabWindows.app` on a clean launch with Accessibility permission granted.
4. Zip the built app:

```bash
ditto -c -k --keepParent AltTabWindows.app AltTabWindows.app.zip
```

5. Attach `AltTabWindows.app.zip` to the GitHub release.

## Project Structure

```
Sources/AltTabWindows/
  App/           — entry point, AppDelegate, AppController, settings window
  HotKey/        — global Option + Tab registration via Carbon API
  Window/        — window collection, models, switching history
  Accessibility/ — reading and activating windows via AX API
  Switcher/      — HUD panel, window cards, screen positioning
```
