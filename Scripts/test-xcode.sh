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

screenshot_path="$temporary_dir/ic067-screen.png"
xcrun simctl bootstatus "$destination_id" -b
xcrun simctl io "$destination_id" screenshot "$screenshot_path"
xcrun simctl addmedia "$destination_id" "$screenshot_path"

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

(
    for _ in $(seq 1 300); do
        if xcrun simctl get_app_container \
            "$destination_id" "$app_bundle_id" app >/dev/null 2>&1; then
            xcrun simctl privacy "$destination_id" grant photos \
                "$app_bundle_id"
            exit 0
        fi
        sleep 0.1
    done
    echo "错误：测试宿主安装后未能及时授予照片权限。" >&2
    exit 1
) &
privacy_grant_pid=$!

xcodebuild \
    test-without-building \
    -project "$project_path" \
    -scheme "$scheme_name" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$destination_id" \
    -derivedDataPath "$temporary_dir/DerivedData"

wait "$privacy_grant_pid"

echo "XCTest 已全部通过。"
