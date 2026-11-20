#!/bin/sh
set -e
cd "$(dirname "$0")/.."

version="${VERSION:-1.1.0}"
archs="--arch arm64 --arch x86_64"

swift build -c release --product Cribbage $archs
app="dist/Tiny Crib.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$(swift build -c release $archs --show-bin-path)/Cribbage" "$app/Contents/MacOS/Cribbage"
cp assets/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Tiny Crib</string>
    <key>CFBundleDisplayName</key><string>Tiny Crib</string>
    <key>CFBundleIdentifier</key><string>io.github.joel1842.tiny-crib</string>
    <key>CFBundleExecutable</key><string>Cribbage</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>$version</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.card-games</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
echo "Built $app ($version)"
