#!/bin/bash
set -euo pipefail

APP_NAME="Deskline"
VERSION="0.2.1"
BUILD_DIR="build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="Deskline-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
STAGING_DIR="${BUILD_DIR}/dmg-staging"
VOLUME_NAME="Deskline ${VERSION}"

if [ ! -d "${APP_PATH}" ]; then
    echo "App not found. Running build first..."
    ./build.sh
fi

echo "Creating ${DMG_NAME}..."

rm -rf "${STAGING_DIR}"
rm -f  "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"

cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "${DMG_PATH}" >/dev/null

rm -rf "${STAGING_DIR}"

SIZE=$(du -h "${DMG_PATH}" | cut -f1)
SHA=$(shasum -a 256 "${DMG_PATH}" | cut -d' ' -f1)

echo ""
echo "Created: ${DMG_PATH} (${SIZE})"
echo "SHA256:  ${SHA}"
echo ""
echo "To open: open \"${DMG_PATH}\""
