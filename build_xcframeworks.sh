#!/bin/bash
set -e

# PROJECT + TARGET SETTINGS
SCHEME="GameKitPlugin"
PROJECT="ios/GameKitPlugin.xcodeproj"
FRAMEWORK_NAME="GameKitPlugin"

# OUTPUT DIRECTORIES
OUTPUT_DIR="addons/gamekit"
BUILD_DIR="build"

echo "=============================="
echo "Building GameKitPlugin for iOS"
echo "=============================="

# Clean previous builds
rm -rf "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

# Function to build a configuration (Debug / Release)
build_config() {
    CONFIG=$1
    ARCHIVE_PATH="$BUILD_DIR/${CONFIG}_ios.xcarchive"
    FRAMEWORK_PATH="$ARCHIVE_PATH/Products/Library/Frameworks/$FRAMEWORK_NAME.framework"
    XCOUTPUT="$OUTPUT_DIR/gamekit_${CONFIG,,}.xcframework"

    echo ""
    echo "→ Building $CONFIG (iOS device arm64 only)..."

    xcodebuild archive \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -configuration "$CONFIG" \
      -sdk iphoneos \
      -archivePath "$ARCHIVE_PATH" \
      SKIP_INSTALL=NO \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      ONLY_ACTIVE_ARCH=NO \
      ARCHS=arm64 \
      > /dev/null

    echo "→ Creating XCFramework: $XCOUTPUT"

    xcodebuild -create-xcframework \
      -framework "$FRAMEWORK_PATH" \
      -output "$XCOUTPUT" \
      > /dev/null

    echo "✔ Finished $XCOUTPUT"
}

# Build both Debug + Release
build_config Debug
build_config Release

echo ""
echo "======================================"
echo "🎉 Done! XCFrameworks generated in:"
echo "   addons/gamekit/"
echo "======================================"
