#!/usr/bin/env bash
#
# Builds rclone's `librclone` as an iOS XCFramework using gomobile and drops it
# into ios/Frameworks/Rclone.xcframework, ready to be linked by the Runner target.
#
# Requirements (run on macOS):
#   - Go >= 1.21            (brew install go)
#   - Xcode + command line tools
#   - gomobile / gobind:
#       go install golang.org/x/mobile/cmd/gomobile@latest
#       go install golang.org/x/mobile/cmd/gobind@latest
#       gomobile init
#
# Usage:
#   ./ios/scripts/build_librclone.sh [RCLONE_VERSION]
#   (defaults to the latest tagged release checked out under build/rclone)
#
set -euo pipefail

RCLONE_VERSION="${1:-v1.68.2}"
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/librclone"
OUT_DIR="${ROOT_DIR}/ios/Frameworks"
OUT_FRAMEWORK="${OUT_DIR}/Rclone.xcframework"

echo "==> Building librclone ${RCLONE_VERSION} for iOS"

mkdir -p "${BUILD_DIR}" "${OUT_DIR}"

if [ ! -d "${BUILD_DIR}/rclone" ]; then
  git clone --depth 1 --branch "${RCLONE_VERSION}" https://github.com/rclone/rclone.git "${BUILD_DIR}/rclone"
fi

cd "${BUILD_DIR}/rclone"

# gomobile bind produces an XCFramework named after the package output.
# The generated Swift module is `Rclone`, matching `import Rclone` in RcloneBridge.swift.
GO111MODULE=on gomobile bind \
  -target=ios \
  -iosversion=13.0 \
  -o "${OUT_FRAMEWORK}" \
  -prefix Rclone \
  ./librclone/gomobile

echo "==> Done: ${OUT_FRAMEWORK}"
echo ""
echo "Next steps (one-time, in Xcode):"
echo "  1. Open ios/Runner.xcworkspace"
echo "  2. Drag ios/Frameworks/Rclone.xcframework into the Runner target"
echo "     (General > Frameworks, Libraries, and Embedded Content = Embed & Sign)."
echo "  3. Build & run: flutter run -d ios"
