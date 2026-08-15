#!/usr/bin/env bash
#
# PondyConnect — Production Release Build Script
#
# Builds obfuscated Android (APK + AAB) and iOS binaries for the
# Consumer, Driver, and Partner app flavors.
#
# Usage:
#   ./build_release.sh                  # Build all flavors (APK + AAB)
#   ./build_release.sh apk              # Build only APKs
#   ./build_release.sh aab              # Build only AABs
#   ./build_release.sh ios              # Build only iOS
#
# Prerequisites:
#   - Flutter SDK on PATH
#   - Android SDK + signing keystore configured in android/key.properties
#   - For iOS: Xcode + provisioning profiles on macOS
#
# The --obfuscate and --split-debug-info flags scramble Dart symbols
# in the compiled binary and save the deobfuscation map separately.
# Keep the debug-info files safe — they are required to decode
# production stack traces.

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Directory to store deobfuscation symbols (one per flavor + platform).
DEBUG_INFO_DIR="$SCRIPT_DIR/build/debug-info"
mkdir -p "$DEBUG_INFO_DIR"

# Flutter flavor → Dart entry point mapping.
# Each flavor has its own main_*.dart entry point.
declare -A FLAVORS=(
  ["consumer"]="lib/main.dart"
  ["driver"]="lib/main_driver.dart"
  ["partner"]="lib/main_partner.dart"
  ["vendor"]="lib/main_vendor.dart"
)

# API base URL — override with: API_BASE_URL=http://1.2.3.4:5000 ./build_release.sh
API_BASE_URL="${API_BASE_URL:-}"
DART_DEFINES=""
if [[ -n "$API_BASE_URL" ]]; then
  DART_DEFINES="--dart-define=API_BASE_URL=$API_BASE_URL"
  log "Using API_BASE_URL: $API_BASE_URL"
fi

# Build mode: apk, aab, ios, or all.
BUILD_TARGET="${1:-all}"

# ── Helpers ────────────────────────────────────────────────────────────

log() {
  printf '\n\033[1;34m[build_release]\033[0m %s\n' "$*"
}

fail() {
  printf '\033[1;31m[build_release] ERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

check_flutter() {
  command -v flutter >/dev/null 2>&1 || fail "Flutter SDK not found on PATH."
}

build_apk() {
  local flavor="$1"
  local entry_point="${FLAVORS[$flavor]}"
  local symbol_file="$DEBUG_INFO_DIR/${flavor}-apk-symbols"

  log "Building obfuscated APK for flavor: $flavor"
  flutter build apk \
    --flavor "$flavor" \
    --target "$entry_point" \
    --release \
    --obfuscate \
    --split-debug-info="$symbol_file" \
    --no-tree-shake-icons \
    --dart-define=APP_FLAVOR=$flavor \
    $DART_DEFINES

  log "APK for $flavor → build/app/outputs/flutter-apk/app-${flavor}-release.apk"
  log "Debug symbols  → $symbol_file"
}

build_aab() {
  local flavor="$1"
  local entry_point="${FLAVORS[$flavor]}"
  local symbol_file="$DEBUG_INFO_DIR/${flavor}-aab-symbols"

  log "Building obfuscated AAB for flavor: $flavor"
  flutter build appbundle \
    --flavor "$flavor" \
    --target "$entry_point" \
    --release \
    --obfuscate \
    --split-debug-info="$symbol_file" \
    --no-tree-shake-icons \
    --dart-define=APP_FLAVOR=$flavor \
    $DART_DEFINES

  log "AAB for $flavor → build/app/outputs/bundle/${flavor}Release/app-${flavor}-release.aab"
  log "Debug symbols  → $symbol_file"
}

build_ios() {
  local flavor="$1"
  local entry_point="${FLAVORS[$flavor]}"
  local symbol_file="$DEBUG_INFO_DIR/${flavor}-ios-symbols"

  log "Building obfuscated iOS for flavor: $flavor"
  flutter build ios \
    --flavor "$flavor" \
    --target "$entry_point" \
    --release \
    --obfuscate \
    --split-debug-info="$symbol_file" \
    --no-tree-shake-icons \
    --dart-define=APP_FLAVOR=$flavor \
    $DART_DEFINES

  log "iOS for $flavor → build/ios/iphoneos/Runner.app"
  log "Debug symbols  → $symbol_file"
}

# ── Main ───────────────────────────────────────────────────────────────

check_flutter

log "PondyConnect production build script"
log "Build target: $BUILD_TARGET"
log "Flavors: ${!FLAVORS[*]}"
log "Debug symbols dir: $DEBUG_INFO_DIR"

case "$BUILD_TARGET" in
  apk)
    for flavor in "${!FLAVORS[@]}"; do
      build_apk "$flavor"
    done
    ;;
  aab)
    for flavor in "${!FLAVORS[@]}"; do
      build_aab "$flavor"
    done
    ;;
  ios)
    for flavor in "${!FLAVORS[@]}"; do
      build_ios "$flavor"
    done
    ;;
  all)
    for flavor in "${!FLAVORS[@]}"; do
      build_apk "$flavor"
      build_aab "$flavor"
    done
    # iOS builds only on macOS.
    if [[ "$(uname -s)" == "Darwin" ]]; then
      for flavor in "${!FLAVORS[@]}"; do
        build_ios "$flavor"
      done
    else
      log "Skipping iOS builds (not on macOS). Run on a Mac for iOS."
    fi
    ;;
  *)
    fail "Unknown build target: $BUILD_TARGET. Use: apk, aab, ios, or all."
    ;;
esac

log "All builds complete!"
log "IMPORTANT: Back up the debug-info files in $DEBUG_INFO_DIR —"
log "they are required to deobfuscate production stack traces."
