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

simulators_json="$(xcrun simctl list devices available -j)"

destination_info="$(
    printf "%s" "$simulators_json" |
        jq -r '
            .devices
            | to_entries[]
            | select(.key | test("com\\.apple\\.CoreSimulator\\.SimRuntime\\.iOS-26-"))
            | . as $entry
            | ($entry.key | capture("iOS-26-(?<minor>[0-9]+)$").minor | tonumber) as $minor
            | $entry.value[]
            | select(.isAvailable == true)
            | select(.name | test("iPhone"))
            | [$minor, .udid, .name] | @tsv
        ' |
        sort -t "$(printf '\t')" -k1,1nr |
        head -n 1
)"

destination_id="$(printf "%s" "$destination_info" | cut -f2)"
destination_name="$(printf "%s" "$destination_info" | cut -f3)"

if [ -z "$destination_id" ]; then
    echo "错误：runner 上没有可用的 iOS 26.x iPhone 模拟器（不静默回落到其他版本）。" >&2
    echo "可用模拟器列表：" >&2
    xcrun simctl list devices available >&2
    exit 1
fi

echo "使用 iPhone 模拟器：${destination_name} (id=${destination_id})"

xcodebuild \
    test \
    -project "$project_path" \
    -scheme "$scheme_name" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$destination_id" \
    -derivedDataPath "$temporary_dir/DerivedData"

echo "XCTest 已全部通过。"
