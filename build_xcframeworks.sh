#!/bin/bash
set -e

SCHEME="GameKitPlugin"
FRAMEWORK_NAME="GameKitPlugin"

OUTPUT_DIR="addons/gamekit"
BUILD_DIR="build"

echo "=== Building GameKit xcframeworks ==="

rm -rf "$OUTPUT_DIR/gamekit_debug.xcframework"        "$OUTPUT_DIR/gamekit_release.xcframework"        "$BUILD_DIR"

mkdir -p "$OUTPUT_DIR"

build_config() {
    CONFIG=$1

    IOS="$BUILD_DIR/${CONFIG}_ios.xcarchive"
    SIM="$BUILD_DIR/${CONFIG}_sim.xcarchive"

    echo "→ Building $CONFIG for device"
    xcodebuild archive       -scheme "$SCHEME"       -configuration "$CONFIG"       -sdk iphoneos       -archivePath "$IOS"       SKIP_INSTALL=NO       BUILD_LIBRARY_FOR_DISTRIBUTION=YES

    echo "→ Building $CONFIG for simulator"
    xcodebuild archive       -scheme "$SCHEME"       -configuration "$CONFIG"       -sdk iphonesimulator       -archivePath "$SIM"       SKIP_INSTALL=NO       BUILD_LIBRARY_FOR_DISTRIBUTION=YES

    OUT="$OUTPUT_DIR/gamekit_${CONFIG,,}.xcframework"

    echo "→ Creating $OUT"
    xcodebuild -create-xcframework       -framework "$IOS/Products/Library/Frameworks/$FRAMEWORK_NAME.framework"       -framework "$SIM/Products/Library/Frameworks/$FRAMEWORK_NAME.framework"       -output "$OUT"

    echo "✔ Built $OUT"
}

build_config Debug
build_config Release

echo "=== Build complete! XCFrameworks stored in addons/gamekit ==="
