#!/bin/bash
# Creates the tvOS cross-compile artifacts on a Mac.
# Products: /tmp/chromium-tvos-toolchain.zip, /tmp/chromium-mac-extra.zip
# Copy both to the Linux machine's $ARTIFACTS_DIR (default: ~/mac-toolchain).
set -euo pipefail

XCODE_APP="${XCODE_APP:-/Applications/Xcode.app}"

# Sanity: tvOS platform must be installed (xcodebuild -downloadPlatform tvOS).
xcrun --sdk appletvsimulator --show-sdk-path >/dev/null

# 1. tvOS simulator SDK + platform frameworks + swift libs bundle
OUT=/tmp/chromium-tvos-toolchain
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$XCODE_APP/Contents/version.plist" "$OUT/"

# SDK (resolve symlinks with -L)
rsync -aL "$XCODE_APP/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk" "$OUT/"

# XCTest etc. platform frameworks (needed by test .app bundles)
mkdir -p "$OUT/AppleTVSimulator.platform/Developer"
rsync -aL "$XCODE_APP/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/Library" \
  "$OUT/AppleTVSimulator.platform/Developer/"

# Swift compatibility libs from the toolchain (linker -L path; may be linked
# once Swift code is actually used).
mkdir -p "$OUT/usr/lib"
rsync -aL "$XCODE_APP/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift" \
  "$OUT/usr/lib/" || true
mkdir -p "$OUT/usr/lib/swift/iphonesimulator"

# Version info consumed by setup_linux.sh to fill args.gn
{
  echo "xcode_version_verbatim: $(xcodebuild -version | awk 'NR==1{print $2}')"
  echo "xcode_build: $(xcodebuild -version | awk 'NR==2{print $3}')"
  echo "sdk_version: $(xcrun --sdk appletvsimulator --show-sdk-version)"
  echo "sdk_build: $(xcrun --sdk appletvsimulator --show-sdk-build-version)"
  echo "machine_os_build: $(sw_vers -buildVersion)"
} > "$OUT/sdk_info.txt"
cat "$OUT/sdk_info.txt"

(cd /tmp && rm -f chromium-tvos-toolchain.zip && zip -qry chromium-tvos-toolchain.zip chromium-tvos-toolchain)

# 2. darwin compiler-rt bundle (includes libclang_rt.tvossim*)
CLANG_LIB_ROOT="$XCODE_APP/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang"
VER="$(find "$CLANG_LIB_ROOT" -maxdepth 1 -mindepth 1 -type d -exec test -d '{}/lib/darwin' ';' -print | head -n1 | xargs basename)"
echo "Using clang runtime version: $VER"
OUT=/tmp/chromium-mac-extra
rm -rf "$OUT"; mkdir -p "$OUT/clang-rt-darwin"
rsync -a "$CLANG_LIB_ROOT/$VER/lib/darwin/" "$OUT/clang-rt-darwin/"
(cd /tmp && rm -f chromium-mac-extra.zip && zip -qry chromium-mac-extra.zip chromium-mac-extra)

echo
echo "Done. Copy these to the Linux machine:"
echo "  /tmp/chromium-tvos-toolchain.zip"
echo "  /tmp/chromium-mac-extra.zip"
