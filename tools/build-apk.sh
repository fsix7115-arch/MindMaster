#!/usr/bin/env bash
# =============================================================================
# MindMaster — Android APK builder
# =============================================================================
# Builds a signed, aligned APK that wraps the fully offline web app.
#
# Requirements:
#   - Android SDK cmdline-tools + platform-34 + build-tools;34.0.0
#   - JDK 17+
#
# Usage:
#   bash tools/build-apk.sh [version]     # e.g. bash tools/build-apk.sh 1.1.0
#
# Output:
#   MindMaster-v<version>.apk  (release-signed, zipaligned)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${1:-1.1.0}"
APK_NAME="MindMaster-v${VERSION}.apk"
OUT_APK="$REPO_ROOT/$APK_NAME"

# ---- Locate the Android SDK ------------------------------------------------
if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
  SDK="$ANDROID_HOME"
elif [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "${ANDROID_SDK_ROOT:-}" ]; then
  SDK="$ANDROID_SDK_ROOT"
elif [ -d "$HOME/Android/Sdk" ]; then
  SDK="$HOME/Android/Sdk"
elif [ -d /tmp/android-sdk ]; then
  SDK=/tmp/android-sdk
else
  echo "ERROR: Android SDK not found. Set ANDROID_HOME." >&2
  exit 1
fi

BUILD_TOOLS="$SDK/build-tools/34.0.0"
PLATFORM="$SDK/platforms/android-34/android.jar"
AAPT="$BUILD_TOOLS/aapt"
D8="$BUILD_TOOLS/d8"
ZIPALIGN="$BUILD_TOOLS/zipalign"
APKSIGNER="$BUILD_TOOLS/apksigner"

for tool in "$AAPT" "$D8" "$ZIPALIGN" "$APKSIGNER"; do
  if [ ! -x "$tool" ]; then
    echo "ERROR: missing tool: $tool" >&2
    exit 1
  fi
done
if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/javac" ]; then
  JAVAC="$JAVA_HOME/bin/javac"
elif [ -x /usr/local/sdkman/candidates/java/21.0.12+1-ms/bin/javac ]; then
  # R8 (build-tools 34) chokes on JDK 25 class files — prefer JDK 21.
  JAVAC=/usr/local/sdkman/candidates/java/21.0.12+1-ms/bin/javac
elif command -v javac >/dev/null 2>&1; then
  JAVAC=javac
else
  echo "ERROR: javac not found" >&2
  exit 1
fi
if [ ! -f "$PLATFORM" ]; then
  echo "ERROR: android-34 platform not installed" >&2
  exit 1
fi

echo "==> SDK:      $SDK"
echo "==> Version:  $VERSION"

# ---- Inject web assets into the Android project ----------------------------
ASSETS_WEB="$REPO_ROOT/android/app/src/main/assets/web"
rm -rf "$ASSETS_WEB"
mkdir -p "$ASSETS_WEB"

# Copy only what the web app needs (skip .git, android/, website/ mirror,
# docs, and the APK itself).
cp "$REPO_ROOT"/*.html "$ASSETS_WEB/"
cp "$REPO_ROOT"/manifest.json "$ASSETS_WEB/"
cp "$REPO_ROOT"/sw.js "$ASSETS_WEB/"
cp -r "$REPO_ROOT/assets" "$ASSETS_WEB/"

# Launcher icons for the APK (adaptive foreground = 512 icon)
ICON_DIR="$REPO_ROOT/android/app/src/main/res"
cp "$REPO_ROOT/assets/icons/icon-512.png" \
   "$ICON_DIR/mipmap-xxxhdpi/ic_launcher.png" 2>/dev/null || \
  { mkdir -p "$ICON_DIR/mipmap-xxxhdpi"; cp "$REPO_ROOT/assets/icons/icon-512.png" "$ICON_DIR/mipmap-xxxhdpi/ic_launcher.png"; }
cp "$REPO_ROOT/assets/icons/icon-192.png" "$ICON_DIR/mipmap-xxxhdpi/ic_launcher_foreground.png" 2>/dev/null || true
cp "$REPO_ROOT/assets/icons/icon-192.png" "$ICON_DIR/mipmap-xxhdpi/ic_launcher.png" 2>/dev/null || true
cp "$REPO_ROOT/assets/icons/icon-144.png" "$ICON_DIR/mipmap-xhdpi/ic_launcher.png" 2>/dev/null || true
cp "$REPO_ROOT/assets/icons/icon-96.png"  "$ICON_DIR/mipmap-hdpi/ic_launcher.png" 2>/dev/null || true
cp "$REPO_ROOT/assets/icons/icon-72.png"  "$ICON_DIR/mipmap-mdpi/ic_launcher.png" 2>/dev/null || true

# Color resource referenced by the adaptive icon
mkdir -p "$ICON_DIR/values"
if ! grep -q "ic_launcher_background" "$ICON_DIR/values/colors.xml" 2>/dev/null; then
  cat > "$ICON_DIR/values/colors.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#05070A</color>
</resources>
EOF
fi

echo "==> Assets injected into android/app/src/main/assets/web/"

# ---- Build ------------------------------------------------------------------
BUILD_DIR="$REPO_ROOT/android/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/gen" "$BUILD_DIR/obj" "$BUILD_DIR/apk"

# 1. Generate R.java + package resources
"$AAPT" package -f -m \
  -S "$REPO_ROOT/android/app/src/main/res" \
  -M "$REPO_ROOT/android/app/src/main/AndroidManifest.xml" \
  -I "$PLATFORM" \
  -J "$BUILD_DIR/gen" \
  -F "$BUILD_DIR/resources.ap_"

echo "==> Resources packaged"

# 2. Compile Java (activity + generated R.java)
JAVASRC=$(find "$REPO_ROOT/android/app/src/main/java" -name '*.java')
if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/javac" ]; then
  JAVAC="$JAVA_HOME/bin/javac"
else
  JAVAC=javac
fi
"$JAVAC" -source 8 -target 8 \
  -classpath "$PLATFORM" \
  -d "$BUILD_DIR/obj" \
  $JAVASRC "$BUILD_DIR/gen/com/mindmaster/app/R.java"

echo "==> Java compiled"

# 3. Convert classes to DEX
CLASSES=$(find "$BUILD_DIR/obj" -name '*.class')
mkdir -p "$BUILD_DIR/dex"
"$D8" --min-api 24 --output "$BUILD_DIR/dex" $CLASSES
cp "$BUILD_DIR/dex/classes.dex" "$BUILD_DIR/classes.dex"

echo "==> DEX produced"

# 4. Add DEX + assets into the package
# NOTE: `aapt add` stores each file under the path it is given, so we
# stage everything under BUILD_DIR/apkroot/ at the exact archive paths
# first, then add each file with its staged (relative) path.
rm -rf "$BUILD_DIR/apkroot"
mkdir -p "$BUILD_DIR/apkroot/assets"
cp "$BUILD_DIR/classes.dex" "$BUILD_DIR/apkroot/classes.dex"
cp -r "$REPO_ROOT/android/app/src/main/assets/." "$BUILD_DIR/apkroot/assets/"

cd "$BUILD_DIR/apkroot"
ASSET_LIST=$(find . -type f | sed 's|^\./||')
for rel in $ASSET_LIST; do
  "$AAPT" add "$BUILD_DIR/resources.ap_" "$rel" >/dev/null
done

echo "==> DEX + assets added to package"

# 5. Zipalign
"$ZIPALIGN" -f 4 "$BUILD_DIR/resources.ap_" "$BUILD_DIR/aligned.apk"

# 6. Sign (release keystore, generated once and kept under android/keystore)
KEYSTORE="$REPO_ROOT/android/keystore/mindmaster.jks"
if [ ! -f "$KEYSTORE" ]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -alias mindmaster \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass mindmaster -keypass mindmaster \
    -dname "CN=MindMaster, O=MindMaster, L=Unknown, ST=Unknown, C=XX" 2>/dev/null
  echo "==> Generated release keystore at android/keystore/mindmaster.jks"
  echo "    (Keep this file safe — it signs every future update.)"
fi

"$APKSIGNER" sign --ks "$KEYSTORE" \
  --ks-pass pass:mindmaster \
  --key-pass pass:mindmaster \
  --ks-key-alias mindmaster \
  --out "$OUT_APK" \
  "$BUILD_DIR/aligned.apk"

echo ""
echo "============================================="
echo "  APK built: $APK_NAME"
echo "  Size: $(du -h "$OUT_APK" | cut -f1)"
echo "============================================="
"$APKSIGNER" verify --print-certs "$OUT_APK" 2>/dev/null | head -4 || true
