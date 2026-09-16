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
            | select(.name == "iPhone 16")
            | [$minor, .udid, .name, $entry.key] | @tsv
        ' |
        sort -t "$(printf '\t')" -k1,1nr |
        head -n 1
)"

destination_id="$(printf "%s" "$destination_info" | cut -f2)"
destination_name="$(printf "%s" "$destination_info" | cut -f3)"
destination_runtime="$(printf "%s" "$destination_info" | cut -f4)"

# IC-126 B：机型钉死为 iPhone 16（与 #239 同机型，数据可比）。找不到即显式失败并
# 打印可用列表；不静默回落到其他机型或其他 iOS 版本。
if [ -z "$destination_id" ]; then
    echo "错误：runner 上没有可用的 iOS 26.x「iPhone 16」模拟器（机型钉死，不回落到其他机型或版本）。" >&2
    echo "可用模拟器列表：" >&2
    xcrun simctl list devices available >&2
    exit 1
fi

echo "使用 iPhone 模拟器：${destination_name} (id=${destination_id}, runtime=${destination_runtime})"
echo "== simctl 实证（IC-126 G423）：选中 runtime 区块内的可用设备 =="
xcrun simctl list devices "${destination_runtime}" available

# IC-154 子项 C：模拟器启动与 xcodebuild test 分段计时，目的是归因、不是提速。
# #304 attempt 1 在测试包链接完成到测试宿主启动之间静默 10 分 38 秒，分不出是模拟器
# 启动还是装载测试宿主；这里先把模拟器显式启动到就绪，两段各自计秒。
# 设备已处于启动状态视为成功；其余启动失败显式失败，不回落到其他设备或版本。
boot_started="$(date +%s)"
if boot_output="$(xcrun simctl boot "${destination_id}" 2>&1)"; then
    if [ -n "${boot_output}" ]; then
        printf '%s\n' "${boot_output}"
    fi
else
    case "${boot_output}" in
        *"Unable to boot device in current state: Booted"*)
            echo "模拟器 ${destination_name} (id=${destination_id}) 已处于启动状态，继续。"
            ;;
        *)
            echo "错误：模拟器 ${destination_name} (id=${destination_id}) 启动失败（不回落到其他设备或版本）。输出如下：" >&2
            printf '%s\n' "${boot_output}" >&2
            exit 1
            ;;
    esac
fi
if ! xcrun simctl bootstatus "${destination_id}" -b; then
    echo "错误：模拟器 ${destination_name} (id=${destination_id}) 未能进入就绪状态。" >&2
    exit 1
fi
boot_seconds=$(( $(date +%s) - boot_started ))

# xcodebuild 失败时 set -e 会直接退出、打不出分段耗时，故包进 if，退出码原样透传。
xcodebuild_started="$(date +%s)"
if xcodebuild \
    test \
    -project "$project_path" \
    -scheme "$scheme_name" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$destination_id" \
    -derivedDataPath "$temporary_dir/DerivedData"
then
    xcodebuild_status=0
else
    xcodebuild_status=$?
fi
xcodebuild_seconds=$(( $(date +%s) - xcodebuild_started ))

# 成功与失败两条路径都打印；「总」是本脚本自启动起的秒数（bash 的 SECONDS）。
segment_summary="模拟器启动 ${boot_seconds} s；xcodebuild test ${xcodebuild_seconds} s；总 ${SECONDS} s"
echo "XCTest 分段耗时：${segment_summary}"
echo "::notice title=XCTest 分段耗时::${segment_summary}"
if [ "${xcodebuild_status}" -ne 0 ]; then
    exit "${xcodebuild_status}"
fi

echo "XCTest 已全部通过。"
