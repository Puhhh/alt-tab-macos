#!/bin/bash
set -e

APP_NAME="AltTabWindows"
APP_DIR="${APP_NAME}.app"

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AltTabWindows</string>
    <key>CFBundleIdentifier</key>
    <string>com.ablbv.alttabwindows</string>
    <key>CFBundleName</key>
    <string>AltTabWindows</string>
    <key>CFBundleDisplayName</key>
    <string>AltTabWindows</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>alt-tab-icon</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Developed by Aleksei Blinov</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

if [ -f "Icon/alt-tab-icon.icns" ]; then
    cp "Icon/alt-tab-icon.icns" "$APP_DIR/Contents/Resources/alt-tab-icon.icns"
fi

codesign --force --deep --sign - "$APP_DIR"

echo "Done: $APP_DIR"
echo "Drag $APP_DIR to /Applications to install."
