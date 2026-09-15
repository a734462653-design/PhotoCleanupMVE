#!/bin/bash
#
# IC-149 子项 B：XCTest 日志的项数统计。
#
# 为什么不能沿用 `grep 'Executed N tests' | tail -n 1`：
# 测试宿主崩溃后 xcodebuild 会重启并只跑「剩下的」用例，日志因此分成多段，
# 每段末尾各有一条自己的 `Executed N tests` 小计。`tail -n 1` 取到的是
# **最后一段**的小计，既不是真实项数，也不带前面段落里的失败数。
# ①实测 #292 attempt 1（run id 34871287047）：真实 777 项、testIC063 用例
# 内 20 条断言失败、宿主随后因 `Fatal access conflict detected` 崩溃；
# 而摘要 notice 报的是 `Executed 401 tests, with 0 failures`——项数少报 376，
# 失败数报 0，一次判红的运行在摘要上看起来是满绿的。
#
# 改用「唯一 Test Case 行去重计数」：无论日志分几段、宿主重启几次，
# 每个用例的身份 -[Suite testName] 只算一次。崩溃在半途的用例也算「已执行」
# （它确实起跑了），因此 #292 attempt 1 的口径是 375 + 1 + 401 = 777。
#
# runner 的 bash 是 GNU bash 3.2.57（IC-125 实证），没有关联数组、没有
# mapfile、没有 ${var,,}；去重与计数一律走 awk，shell 侧只做参数校验与输出。
#
# 用法：summarize-xctest-log.sh <日志文件>
# 输出（每行一个 key=value，供 ci.yml 用 sed 取值）：
#   executed_count=<整次运行的唯一用例数>
#   failed_case_count=<至少有一条失败记录的唯一用例数>
#   restart_count=<测试宿主重启次数>
#   launch_count=<日志段数 = restart_count + 1>
#   summary_line=<给 ::notice 用的单行摘要>
#
# summary_line 里「Executed N tests」只出现一处，且 N 就是真实项数：
# ci.yml 的 IC-125 哨兵用 `s/.*Executed ([0-9]+) tests?.*/\1/` 取值，
# 前缀 .* 是贪婪的，一行里出现第二处 Executed 会让哨兵取到后一个数。
# 末段小计因此只写数字、不带 Executed 字样。改这一行前先想清楚这件事。
#
# 退出码：0 正常产出；2 参数错误。日志本身是红是绿不由本脚本判定——
# 判红判绿仍由 ci.yml 的真实退出码与 IC-125 哨兵负责，本脚本只报数。

set -u

log_file="${1:-}"
if [ -z "${log_file}" ]; then
    echo "summarize-xctest-log.sh: 缺少日志文件参数。" >&2
    exit 2
fi
if [ ! -f "${log_file}" ]; then
    echo "summarize-xctest-log.sh: 日志文件不存在：${log_file}" >&2
    exit 2
fi

awk '
function identity(text) {
    # 从 Test Case 行或断言失败行中取出 -[Suite testName] 这个身份串。
    if (match(text, /-\[[^]]+\]/)) {
        return substr(text, RSTART, RLENGTH)
    }
    return ""
}

BEGIN {
    executed = 0
    failed = 0
    restarts = 0
    last_count = ""
    last_failures = ""
}

{
    # 夹具是 .log，.gitattributes 没有为它定 eol，Windows 检出可能带 CR。
    # 统计口径不该随检出设置漂移，先把行尾的 CR 去掉。
    sub(/\r$/, "")
}

/Restarting after unexpected exit, crash, or test timeout/ {
    restarts = restarts + 1
}

/Executed [0-9]+ tests?/ {
    if (match($0, /Executed [0-9]+/)) {
        piece = substr($0, RSTART, RLENGTH)
        sub(/Executed /, "", piece)
        last_count = piece
    }
    if (match($0, /with [0-9]+ failures?/)) {
        piece = substr($0, RSTART, RLENGTH)
        sub(/with /, "", piece)
        sub(/ failures?/, "", piece)
        last_failures = piece
    }
}

/Test Case / {
    id = identity($0)
    if (id != "") {
        if (!(id in seen_case)) {
            seen_case[id] = 1
            executed = executed + 1
        }
        if ($0 ~ / failed \(/) {
            if (!(id in seen_failed)) {
                seen_failed[id] = 1
                failed = failed + 1
            }
        }
    }
}

/: error: -\[/ {
    id = identity($0)
    if (id != "") {
        # 断言失败行先于 "Test Case ... failed" 出现；宿主崩溃时后者根本不会
        # 被打印（#292 attempt 1 即如此），所以失败用例必须也从这里认。
        if (!(id in seen_case)) {
            seen_case[id] = 1
            executed = executed + 1
        }
        if (!(id in seen_failed)) {
            seen_failed[id] = 1
            failed = failed + 1
        }
    }
}

END {
    launches = restarts + 1
    printf "executed_count=%d\n", executed
    printf "failed_case_count=%d\n", failed
    printf "restart_count=%d\n", restarts
    printf "launch_count=%d\n", launches
    line = sprintf("Executed %d tests, %d failing test case(s), across %d launch(es)", executed, failed, launches)
    if (restarts > 0) {
        line = line " [test host restarted]"
    }
    if (last_count != "") {
        # 末段小计只写数字，不带 Executed 字样——理由见文件头。
        line = line "; xcodebuild last-chunk subtotal: " last_count " tests"
        if (last_failures != "") {
            line = line " / " last_failures " failures"
        }
    }
    printf "summary_line=%s\n", line
}
' "${log_file}"
