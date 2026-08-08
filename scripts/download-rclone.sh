#!/usr/bin/env bash
# Download rclone binaries for bundling into the Fibu app.
# Run once before building:  chmod +x scripts/download-rclone.sh && ./scripts/download-rclone.sh
set -euo pipefail

RCLONE_VERSION="${RCLONE_VERSION:-current}"   # or pin, e.g. "v1.68.2"
BASE_URL="https://downloads.rclone.org/${RCLONE_VERSION}"

echo "==> Fetching rclone version info from ${BASE_URL}/version.txt"
VERSION=$(curl -fsSL "${BASE_URL}/version.txt" | tr -d '[:space:]')
echo "    rclone ${VERSION}"

# ─── Android arm64-v8a ────────────────────────────────────────────────────────
ANDROID_OUT="modules/rclone/android/src/main/assets/rclone"
mkdir -p "$ANDROID_OUT"

ANDROID_ZIP="rclone-${VERSION}-android-arm64.zip"
echo "==> Downloading ${ANDROID_ZIP} …"
curl -fL "${BASE_URL}/${ANDROID_ZIP}" -o "/tmp/${ANDROID_ZIP}"
unzip -p "/tmp/${ANDROID_ZIP}" "*/rclone" > "${ANDROID_OUT}/rclone"
chmod +x "${ANDROID_OUT}/rclone"
echo "$VERSION" > "${ANDROID_OUT}/version.txt"
echo "    Android arm64 → ${ANDROID_OUT}/rclone"

# ─── iOS arm64 ───────────────────────────────────────────────────────────────
# rclone provides an osx-arm64 build; rename it for the iOS bundle.
# Note: rclone on iOS requires a jailbreak or side-loading entitlement
# (com.apple.security.cs.allow-unsigned-executable-memory).
# For TestFlight / App Store builds the binary must be signed with the
# appropriate entitlements.
IOS_OUT="modules/rclone/ios/Resources/rclone"
mkdir -p "$IOS_OUT"

IOS_ZIP="rclone-${VERSION}-osx-arm64.zip"
echo "==> Downloading ${IOS_ZIP} …"
curl -fL "${BASE_URL}/${IOS_ZIP}" -o "/tmp/${IOS_ZIP}"
unzip -p "/tmp/${IOS_ZIP}" "*/rclone" > "${IOS_OUT}/rclone"
chmod +x "${IOS_OUT}/rclone"
echo "$VERSION" > "${IOS_OUT}/version.txt"
echo "    iOS arm64 → ${IOS_OUT}/rclone"

# ─── Cleanup ─────────────────────────────────────────────────────────────────
rm -f "/tmp/${ANDROID_ZIP}" "/tmp/${IOS_ZIP}"

echo ""
echo "Done. Add the following to your build steps before 'expo prebuild':"
echo "  ./scripts/download-rclone.sh"
echo ""
echo "Android: assets are picked up automatically by the Gradle build."
echo "iOS:     add the 'rclone' Resources folder to your Xcode target's"
echo "         Copy Bundle Resources build phase."
