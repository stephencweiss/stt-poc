#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --product STTPractice -Xswiftc -warnings-as-errors
binary_dir=$(swift build --show-bin-path)
app_dir=.build/STTPractice.app
mkdir -p "$app_dir/Contents/MacOS"
cp -f "$binary_dir/STTPractice" "$app_dir/Contents/MacOS/STTPractice"
cp -f Resources/Info.plist "$app_dir/Contents/Info.plist"
plutil -lint "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
echo "Built $app_dir"
