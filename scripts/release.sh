#!/bin/bash
# Builds signs notarizes and staples Xcode RPC for public distribution
# Requires a Developer ID Application cert and a stored notarytool profile
# Usage  ./scripts/release.sh
set -euo pipefail

cd "$(dirname "$0")/.."

KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-xrpc-notary}"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/XRPC.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/Xcode RPC.app"

# full Xcode is required since command line tools cannot archive
if [ -d /Applications/Xcode.app ]; then
	export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

# fail early if the signing cert is missing rather than midway through a build
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
	echo "error  no Developer ID Application certificate found" >&2
	echo "create one in Xcode  Settings  Accounts  Manage Certificates" >&2
	exit 1
fi

if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1; then
	echo "error  no notarytool profile named $KEYCHAIN_PROFILE" >&2
	echo "run  xcrun notarytool store-credentials $KEYCHAIN_PROFILE --apple-id <you> --team-id LP92N2QT42" >&2
	exit 1
fi

rm -rf "$BUILD_DIR"

echo "==> archiving"
xcodebuild -workspace XRPC.xcworkspace -scheme XRPC -configuration Release \
	-archivePath "$ARCHIVE" archive

echo "==> exporting with Developer ID"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
	-exportOptionsPlist scripts/ExportOptions.plist \
	-exportPath "$EXPORT_DIR"

# notarization only accepts zip or dmg not a bare bundle
echo "==> zipping for submission"
UPLOAD="$BUILD_DIR/upload.zip"
ditto -c -k --keepParent "$APP" "$UPLOAD"

echo "==> notarizing  this can take a few minutes"
xcrun notarytool submit "$UPLOAD" --keychain-profile "$KEYCHAIN_PROFILE" --wait

# stapling embeds the ticket so the app validates without a network round trip
echo "==> stapling"
xcrun stapler staple "$APP"

# repackage after stapling since the uploaded zip predates the ticket
echo "==> packaging release artifact"
RELEASE="$BUILD_DIR/XcodeRPC.zip"
rm -f "$RELEASE"
ditto -c -k --keepParent "$APP" "$RELEASE"

echo "==> verifying"
codesign --verify --deep --strict --verbose=2 "$APP"
xcrun stapler validate "$APP"
spctl -a -vvv -t exec "$APP"

echo
echo "done  $RELEASE"
