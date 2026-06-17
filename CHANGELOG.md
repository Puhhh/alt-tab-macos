# Changelog

All notable changes to this project will be documented in this file.

## [1.0.2] - 2026-06-17

### Security

- Sanitized window titles pulled from external apps before they reach the switcher UI or identity matching logic, reducing spoofing and layout issues from control characters, newlines, and excessively long titles.

## [1.0.1] - 2026-05-30

### Changed

- Bumped the app bundle version metadata to `1.0.1` / build `2` in `make-app.sh`.

## [1.0] - 2026-05-30

### Added

- Initial public release of AltTabWindows, a native macOS utility for switching individual windows with `Option + Tab`.
- HUD-based window switcher, Accessibility-driven window focusing, menu bar status UI, and multi-display HUD positioning.
- GitHub Actions release workflow that builds `AltTabWindows.app`, verifies the ad-hoc signature, packages `AltTabWindows.app.zip`, and publishes the GitHub release.

### Changed

- Updated the release checklist in `README.md` to use tag-based GitHub release publishing.
- Added `AltTabWindows.app.zip` to `.gitignore` so packaged release artifacts stay local.

### Fixed

- Improved handling for windows with duplicate names.
