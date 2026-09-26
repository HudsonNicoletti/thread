#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
swift build -c release
APP=.build/Thread.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Thread "$APP/Contents/MacOS/Thread"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Thread</string>
<key>CFBundleIdentifier</key><string>com.nicoletti.thread</string>
<key>CFBundleName</key><string>Thread</string>
<key>CFBundleDisplayName</key><string>Thread</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.0</string>
<key>CFBundleVersion</key><string>5</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
plutil -lint "$APP/Contents/Info.plist"
echo "$PWD/$APP"
