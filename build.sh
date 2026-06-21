#!/bin/bash
set -euo pipefail

APP_NAME="Deskline"
BINARY_NAME="Deskline"
BUNDLE_ID="com.flukeTP.deskline"
VERSION="0.2.1"
BUILD_DIR="build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
ICON_SRC="icon.png"

echo "Building ${APP_NAME} v${VERSION}..."

swift build -c release --arch arm64 --arch x86_64 2>&1 || swift build -c release 2>&1

echo "Creating .app bundle..."
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"

if [ -f ".build/apple/Products/Release/${BINARY_NAME}" ]; then
  cp ".build/apple/Products/Release/${BINARY_NAME}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"
elif [ -f ".build/release/${BINARY_NAME}" ]; then
  cp ".build/release/${BINARY_NAME}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"
else
  echo "Binary not found after build" >&2
  exit 1
fi
chmod +x "${APP_PATH}/Contents/MacOS/${APP_NAME}"

if [ -f "${ICON_SRC}" ]; then
  echo "Generating AppIcon.icns from ${ICON_SRC}..."
  ICONSET="${BUILD_DIR}/AppIcon.iconset"
  rm -rf "${ICONSET}"
  mkdir -p "${ICONSET}"

  sips -z 16 16     "${ICON_SRC}" --out "${ICONSET}/icon_16x16.png"      >/dev/null
  sips -z 32 32     "${ICON_SRC}" --out "${ICONSET}/icon_16x16@2x.png"   >/dev/null
  sips -z 32 32     "${ICON_SRC}" --out "${ICONSET}/icon_32x32.png"      >/dev/null
  sips -z 64 64     "${ICON_SRC}" --out "${ICONSET}/icon_32x32@2x.png"   >/dev/null
  sips -z 128 128   "${ICON_SRC}" --out "${ICONSET}/icon_128x128.png"    >/dev/null
  sips -z 256 256   "${ICON_SRC}" --out "${ICONSET}/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "${ICON_SRC}" --out "${ICONSET}/icon_256x256.png"    >/dev/null
  sips -z 512 512   "${ICON_SRC}" --out "${ICONSET}/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "${ICON_SRC}" --out "${ICONSET}/icon_512x512.png"    >/dev/null
  sips -z 1024 1024 "${ICON_SRC}" --out "${ICONSET}/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "${ICONSET}" -o "${APP_PATH}/Contents/Resources/AppIcon.icns"
  rm -rf "${ICONSET}"
fi

cat > "${APP_PATH}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 flukeTP. MIT License.</string>
</dict>
</plist>
PLIST

printf "APPL????" > "${APP_PATH}/Contents/PkgInfo"

if [ -d "Sources/Resources" ]; then
  cp -R Sources/Resources/. "${APP_PATH}/Contents/Resources/"
fi

if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -w 18 -h 18 Sources/Resources/menubar-icon.svg -o "${APP_PATH}/Contents/Resources/menubar-icon.png" 2>/dev/null || true
  rsvg-convert -w 36 -h 36 Sources/Resources/menubar-icon.svg -o "${APP_PATH}/Contents/Resources/menubar-icon@2x.png" 2>/dev/null || true
fi

codesign --force --deep --sign - "${APP_PATH}" 2>/dev/null || true
touch "${APP_PATH}"

echo ""
echo "Built: ${APP_PATH}"
echo "Make DMG: ./release.sh"
