#!/bin/bash
#
# IC-154 子项 B：XCTest 日志的失败行提取。
#
# 改前 ci.yml 用一条 grep 取失败行、只留最后 50 行，再逐行发 ::error 注解。两处问题：
# 1. 候选行多于 50 条时，前面的行被丢掉——而最先出现的断言失败往往最能说明问题；
# 2. GitHub 每一步至多保留 10 条 error 注解，超出的静默丢弃。①实测 #292 attempt 1：
#    该步发出 22 条 ::error，注解列表里只剩最先发出的 10 条，runner 自己那条
#    「Process completed with exit code」也没进去（#298 attempt 1 可见它与 ::error
#    同占一步的额度）。
#
# 本脚本扫描整份日志，按优先序排列并去重。优先序（先取先发；同一类内按首次出现的先后）：
#   一、Test Case … failed 行；
#   二、测试目标 PhotoCleanupMVETests/…error: 行，按「文件:行」去重，同一断言行只留首条；
#   三、产品目标 PhotoCleanupMVE/…error: 行（第二类以外的）；
#   四、结论行：Fatal …、Restarting after unexpected exit, crash, or test timeout、
#       ** TEST FAILED **、Process completed with exit code。
# 一行只归入它命中的最靠前的一类；第二类以外一律按整行文本去重。
# 这四类的匹配范围包含改前 grep 的全部三种模式，改前能取到的行，改后一行不少。
#
# 行的规整：去掉行尾 CR（夹具 .log 在 .gitattributes 里没有 eol 规则，Windows 检出会带 CR）；
# 去掉行首的 GitHub 日志时间戳（下载的整包日志与 Scripts/fixtures/ 的夹具带，
# runner 上 tee 出来的日志不带）。
#
# 输出里的「Executed」一律改写为「executed」。ci.yml 的 IC-125 哨兵对含 Executed 的行
# 贪婪取值（见 summarize-xctest-log.sh 文件头）；本脚本的输出虽不进 summary_line，
# 也不给日后任何拼接留机会。日志原文不受影响。
#
# runner 的 bash 是 GNU bash 3.2.57，awk 是 macOS 自带的 BWK awk：shell 侧不用关联数组、
# mapfile、${var,,}；awk 侧不用 gawk 扩展，正则不用区间 {n}。去重与排序全在 awk 里做。
#
# 用法：extract-xctest-failures.sh <日志文件>
# 输出（前三行 key=value，随后两个段）：
#   candidate_count=<匹配到的原始行数，含重复>
#   unique_count=<去重后的条数>
#   annotation_count=<该发注解的条数，至多 annotation_limit>
#   --- annotations ---
#   <全部去重行的前 annotation_count 条>
#   --- all ---
#   <全部去重行>
#
# 退出码：0 正常产出；2 参数错误。日志本身是红是绿不由本脚本判定——
# 判红判绿仍由 ci.yml 的真实退出码与 IC-125 哨兵负责，本脚本只报行。

set -u

# GitHub 每步 error 注解的保留上限。
annotation_limit=10

log_file="${1:-}"
if [ -z "${log_file}" ]; then
    echo "extract-xctest-failures.sh: 缺少日志文件参数。" >&2
    exit 2
fi
if [ ! -f "${log_file}" ]; then
    echo "extract-xctest-failures.sh: 日志文件不存在：${log_file}" >&2
    exit 2
fi

awk -v annotation_limit="${annotation_limit}" '
function normalized(text) {
    sub(/\r$/, "", text)
    sub(/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9][.0-9]*Z /, "", text)
    return text
}

function remember(kind, key, text) {
    candidate_count = candidate_count + 1
    if ((kind, key) in seen) {
        return
    }
    seen[kind, key] = 1
    kept_count[kind] = kept_count[kind] + 1
    kept[kind, kept_count[kind]] = text
}

function displayed(text) {
    gsub(/Executed/, "executed", text)
    return text
}

function is_conclusion(text) {
    if (text ~ /^Fatal / || text ~ /[^A-Za-z]Fatal /) {
        return 1
    }
    if (index(text, "Restarting after unexpected exit, crash, or test timeout") > 0) {
        return 1
    }
    if (index(text, "** TEST FAILED **") > 0) {
        return 1
    }
    if (index(text, "Process completed with exit code") > 0) {
        return 1
    }
    return 0
}

BEGIN {
    candidate_count = 0
    for (category = 1; category <= 4; category++) {
        kept_count[category] = 0
    }
}

{
    line = normalized($0)
    if (line ~ /Test Case .* failed/) {
        remember(1, line, line)
    } else if (line ~ /PhotoCleanupMVETests\/.*error:/) {
        location = line
        if (match(line, /PhotoCleanupMVETests\/[^:]*:[0-9]+/)) {
            location = substr(line, RSTART, RLENGTH)
        }
        remember(2, location, line)
    } else if (line ~ /PhotoCleanupMVE\/.*error:/) {
        remember(3, line, line)
    } else if (is_conclusion(line)) {
        remember(4, line, line)
    }
}

END {
    unique_count = 0
    for (category = 1; category <= 4; category++) {
        unique_count = unique_count + kept_count[category]
    }
    annotation_count = unique_count
    if (annotation_count > annotation_limit + 0) {
        annotation_count = annotation_limit + 0
    }

    printf "candidate_count=%d\n", candidate_count
    printf "unique_count=%d\n", unique_count
    printf "annotation_count=%d\n", annotation_count

    print "--- annotations ---"
    emitted = 0
    for (category = 1; category <= 4; category++) {
        for (position = 1; position <= kept_count[category]; position++) {
            if (emitted < annotation_count) {
                print displayed(kept[category, position])
                emitted = emitted + 1
            }
        }
    }

    print "--- all ---"
    for (category = 1; category <= 4; category++) {
        for (position = 1; position <= kept_count[category]; position++) {
            print displayed(kept[category, position])
        }
    }
}
' "${log_file}"
