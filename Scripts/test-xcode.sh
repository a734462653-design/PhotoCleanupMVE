#!/bin/bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
project_path="$project_root/PhotoCleanupMVE.xcodeproj"
scheme_name="PhotoCleanupMVE"

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "错误：当前环境没有 xcodebuild，必须在安装 Xcode 的 macOS 上执行。" >&2
    exit 1
fi

temporary_dir="$(mktemp -d -t PhotoCleanupMVE-tests.XXXXXX)"
cleanup() {
    rm -rf "$temporary_dir"
}
trap cleanup EXIT

destinations="$(
    xcodebuild \
        -project "$project_path" \
        -scheme "$scheme_name" \
        -showdestinations
)"

destination_id="$(
    printf "%s\n" "$destinations" |
        awk -F'id:' '/platform:iOS Simulator/ && /name:iPhone/ {
            split($2, fields, ",")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", fields[1])
            print fields[1]
            exit
        }'
)"

if [ -z "$destination_id" ]; then
    echo "错误：没有可用的 iPhone 模拟器。" >&2
    printf "%s\n" "$destinations" >&2
    exit 1
fi

echo "使用 iPhone 模拟器：$destination_id"

xcrun simctl bootstatus "$destination_id" -b
simulator_app_path="$(xcode-select -p)/Applications/Simulator.app"
open "$simulator_app_path"
osascript <<'APPLESCRIPT'
tell application "Simulator" to activate
tell application "System Events"
    repeat 40 times
        if exists process "Simulator" then
            tell process "Simulator"
                if exists menu item "Trigger Screenshot" of menu "Device" of menu bar 1 then
                    click menu item "Trigger Screenshot" of menu "Device" of menu bar 1
                    return
                end if
            end tell
        end if
        delay 0.25
    end repeat
end tell
error "未找到 Simulator 的 Trigger Screenshot 菜单项"
APPLESCRIPT
sleep 3

xcodebuild \
    build-for-testing \
    -project "$project_path" \
    -scheme "$scheme_name" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$destination_id" \
    -derivedDataPath "$temporary_dir/DerivedData"

app_path="$temporary_dir/DerivedData/Build/Products/Debug-iphonesimulator/PhotoCleanupMVE.app"
test -d "$app_path"
app_bundle_id="com.iphonephotomanagement.PhotoCleanupMVE"
xcrun simctl uninstall "$destination_id" "$app_bundle_id" >/dev/null 2>&1 || true
xcrun simctl install "$destination_id" "$app_path"
xcrun simctl privacy "$destination_id" reset photos "$app_bundle_id"
xcodebuild \
    test-without-building \
    -project "$project_path" \
    -scheme "$scheme_name" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$destination_id" \
    -derivedDataPath "$temporary_dir/DerivedData" \
    -only-testing:PhotoCleanupMVEUITests/IC067ScreenshotSubtypeProbeUITests/testCroppedScreenshotRetainsScreenshotSubtype

xcodebuild \
    test-without-building \
    -project "$project_path" \
    -scheme "$scheme_name" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$destination_id" \
    -derivedDataPath "$temporary_dir/DerivedData" \
    -only-testing:PhotoCleanupMVETests

echo "XCTest 已全部通过。"
