#!/bin/bash
set -e

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIST_DIR="$PROJECT_ROOT/dist"
ANDROID_BUILD_DIR="$PROJECT_ROOT/build/app/outputs/flutter-apk"
BUILD_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
TEMP_BUILD_DIR="$PROJECT_ROOT/build/packaging_temp"
TEMPLATE_FILE="$PROJECT_ROOT/linux/packaging/PKGBUILD.template"

cd "$PROJECT_ROOT"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

APP_NAME=$(grep 'name:' pubspec.yaml | head -n 1 | awk '{print $2}')
APP_VERSION=$(grep 'version:' pubspec.yaml | head -n 1 | awk '{print $2}' | cut -d+ -f1) # remove build number (+1)
EXE_NAME=$APP_NAME # Usually the executable name matches the pubspec name

echo "🚀 Starting build for android..."

flutter build apk --split-per-abi

mv "$ANDROID_BUILD_DIR/"*"-release.apk" "$DIST_DIR"

echo ""
echo ""
echo "🚀 Starting build for linux..."
flutter build linux --release

echo "📦 Creating source tarball..."
TAR_FILENAME="${APP_NAME}-${APP_VERSION}.tar.gz"

if [ -f "linux/runner/${APP_NAME}.desktop" ]; then
   cp "linux/runner/${APP_NAME}.desktop" "$BUILD_DIR/"
elif [ -f "linux/${APP_NAME}.desktop" ]; then
   cp "linux/${APP_NAME}.desktop" "$BUILD_DIR/"
else
   echo "⚠️ Warning: .desktop file not found in linux/ or linux/runner/. Desktop entry might be missing."
fi

ICON_FILE=$(find assets -name "*.png" | head -n 1)
echo "$ICON_FILE"
if [ -n "$ICON_FILE" ]; then
    cp "$ICON_FILE" "$BUILD_DIR/"
else
    echo "⚠️  WARNING: No .png icon found in linux/!"
fi

cd "$BUILD_DIR"
tar -czf "$DIST_DIR/$TAR_FILENAME" ./*
cd "$PROJECT_ROOT"

APP_HASH=$(sha256sum "$DIST_DIR/$TAR_FILENAME" | awk '{print $1}')
echo "   Hash: $APP_HASH"

echo "📝 Generating PKGBUILD..."
rm -rf "$TEMP_BUILD_DIR"
mkdir -p "$TEMP_BUILD_DIR"

cp "$DIST_DIR/$TAR_FILENAME" "$TEMP_BUILD_DIR/"
sed \
    -e "s/{{APP_NAME}}/$APP_NAME/g" \
    -e "s/{{APP_VERSION}}/$APP_VERSION/g" \
    -e "s/{{APP_HASH}}/$APP_HASH/g" \
    -e "s/{{TAR_FILENAME}}/$TAR_FILENAME/g" \
    -e "s/{{EXE_NAME}}/$EXE_NAME/g" \
    "$TEMPLATE_FILE" > "$TEMP_BUILD_DIR/PKGBUILD"

echo "🏗️  Running makepkg..."
cd "$TEMP_BUILD_DIR"
makepkg -f

echo "🚚 Moving artifacts to dist/..."
mv *.pkg.tar.zst "$DIST_DIR/"

cd "$PROJECT_ROOT"
rm -rf "$TEMP_BUILD_DIR"

echo "✅ Done! Files are in dist/:"
ls -lh "$DIST_DIR"