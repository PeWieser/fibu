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

# Statt: RCLONE_VERSION="${1:-v1.68.2}"
RCLONE_VERSION="${1:-$(curl -s https://api.github.com/repos/rclone/rclone/releases/latest | grep '"tag_name"' | cut -d '"' -f 4 || echo "")}"
if [ -z "${RCLONE_VERSION}" ]; then
  echo "WARN: Could not fetch latest rclone version via GitHub API (rate limit?), using fallback v1.70.0"
  RCLONE_VERSION="v1.70.0"
fi
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/librclone"
OUT_DIR="${ROOT_DIR}/ios/Frameworks"
OUT_FRAMEWORK="${OUT_DIR}/Rclone.xcframework"

echo "==> Building librclone ${RCLONE_VERSION} for iOS"

mkdir -p "${BUILD_DIR}" "${OUT_DIR}"

if [ ! -d "${BUILD_DIR}/rclone" ]; then
  git clone --depth 1 --branch "${RCLONE_VERSION}" https://github.com/rclone/rclone.git "${BUILD_DIR}/rclone"
else
  echo "==> Existing rclone checkout found at ${BUILD_DIR}/rclone, checking version..."
  CURRENT_TAG=$(git -C "${BUILD_DIR}/rclone" describe --tags --exact-match 2>/dev/null || git -C "${BUILD_DIR}/rclone" rev-parse --abbrev-ref HEAD || echo "unknown")
  if [ "${CURRENT_TAG}" != "${RCLONE_VERSION}" ]; then
    echo "==> Version mismatch (current: ${CURRENT_TAG}, wanted: ${RCLONE_VERSION}), re-cloning..."
    rm -rf "${BUILD_DIR}/rclone"
    git clone --depth 1 --branch "${RCLONE_VERSION}" https://github.com/rclone/rclone.git "${BUILD_DIR}/rclone"
  else
    echo "==> Using existing rclone ${CURRENT_TAG}"
  fi
fi

cd "${BUILD_DIR}/rclone"
go mod edit -replace=github.com/shoenig/go-m1cpu=github.com/shoenig/go-m1cpu@v0.1.7 || echo "WARN: go mod edit failed (maybe already set)"

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
