param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$项目根 = Split-Path -Parent $PSScriptRoot
$工作区 = Split-Path -Parent $项目根
$矩阵路径 = Join-Path $项目根 "Reports/TRACEABILITY-S3-S5.md"
$自验报告路径 = Join-Path $项目根 "Reports/IC-20260812-011-SELF-VERIFICATION.md"
$测试根 = Join-Path $项目根 "PhotoCleanupMVETests"
$基线 = "5a76d734a9783e303ff44646928a687155946708"
$失败清单 = [System.Collections.Generic.List[string]]::new()
$检查总数 = 0

function 记录失败 {
    param([string]$消息)
    $失败清单.Add($消息)
}

function 检查 {
    param([bool]$条件, [string]$失败消息)
    $script:检查总数++
    if (-not $条件) {
        记录失败 $失败消息
    }
}

function 取标记区间 {
    param([string[]]$行, [string]$开始标记, [string]$结束标记)
    $开始 = [Array]::IndexOf($行, $开始标记)
    $结束 = [Array]::IndexOf($行, $结束标记)
    if ($开始 -lt 0 -or $结束 -le $开始) {
        记录失败 "报告缺少或错置标记：$开始标记 / $结束标记"
        return @()
    }
    return @($行[($开始 + 1)..($结束 - 1)])
}

function 分割逗号列表 {
    param([string]$文本)
    if ([string]::IsNullOrWhiteSpace($文本) -or $文本 -ceq "—") {
        return @()
    }
    return @($文本 -split ",\s*" | Where-Object { $_ })
}

function 解析三列汇总表 {
    param([string[]]$区间)
    $结果 = @{}
    foreach ($行 in $区间) {
        if ($行 -notmatch '^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$') {
            continue
        }
        $编号 = $Matches[1].Trim()
        if ($编号 -eq "条款编号" -or $编号 -eq "---") {
            continue
        }
        if ($结果.ContainsKey($编号)) {
            记录失败 "汇总表存在重复条款编号：$编号"
        }
        else {
            $结果[$编号] = $Matches[3].Trim()
        }
    }
    return $结果
}

function 解析两列测试表 {
    param([string[]]$区间)
    $结果 = @{}
    foreach ($行 in $区间) {
        if ($行 -notmatch '^\|\s*`?([^|`]+?)`?\s*\|\s*([^|]+?)\s*\|$') {
            continue
        }
        $方法名 = $Matches[1].Trim()
        if ($方法名 -eq "XCTest 方法名" -or $方法名 -eq "---") {
            continue
        }
        if ($结果.ContainsKey($方法名)) {
            记录失败 "未命中测试清单存在重复方法：$方法名"
        }
        else {
            $结果[$方法名] = $Matches[2].Trim()
        }
    }
    return $结果
}

检查 (Test-Path -LiteralPath $矩阵路径 -PathType Leaf) "缺少正反向矩阵报告"
检查 (Test-Path -LiteralPath $自验报告路径 -PathType Leaf) "缺少自验报告"
if (-not (Test-Path -LiteralPath $矩阵路径 -PathType Leaf)) {
    Write-Host "自验失败：无法继续解析矩阵。" -ForegroundColor Red
    exit 1
}

$规格预期 = [ordered]@{
    "SPEC-S3-S4-20260812.v6.md" = [ordered]@{
        路径 = Join-Path $工作区 "SPEC-S3-S4-20260812.v6.md"
        摘要 = "BF52BBE87692A253BDA9C2AC8B55712C76AB453E3AAF6C5D286BC15835E04C7D"
        前缀 = "C34"
        条款数 = 230
    }
    "SPEC-S5-20260812.v5.md" = [ordered]@{
        路径 = Join-Path $工作区 "SPEC-S5-20260812.v5.md"
        摘要 = "10CD2B7829126ABBD8FB66091B21169E698868CA67E345D0EABBA39D8D6221B7"
        前缀 = "C5"
        条款数 = 146
    }
}

$规格行 = @{}
foreach ($规格项 in $规格预期.GetEnumerator()) {
    $信息 = $规格项.Value
    $存在 = Test-Path -LiteralPath $信息.路径 -PathType Leaf
    检查 $存在 "缺少输入规格：$($规格项.Key)"
    if (-not $存在) {
        continue
    }
    $实际摘要 = (Get-FileHash -LiteralPath $信息.路径 -Algorithm SHA256).Hash
    检查 ($实际摘要 -ceq $信息.摘要) "输入规格摘要不匹配：$($规格项.Key)"
    $规格行[$规格项.Key] = @(Get-Content -LiteralPath $信息.路径 -Encoding UTF8)
}

$报告行 = @(Get-Content -LiteralPath $矩阵路径 -Encoding UTF8)
$正向区间 = 取标记区间 $报告行 "<!-- 正向矩阵开始 -->" "<!-- 正向矩阵结束 -->"
$正向数据行 = @(
    $正向区间 |
        Where-Object { $_ -ne '```' -and -not $_.StartsWith("条款编号`t", [System.StringComparison]::Ordinal) }
)

$正向记录 = [System.Collections.Generic.List[object]]::new()
$条款编号集合 = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$允许判定 = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
@("已覆盖", "未覆盖", "不适用") | ForEach-Object { [void]$允许判定.Add($_) }
$允许不适用理由 = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
@("MVE 范围外", "该条款为未定项阻断", "该条款为纯文案", "该条款为纯视觉") |
    ForEach-Object { [void]$允许不适用理由.Add($_) }

foreach ($行 in $正向数据行) {
    $字段 = @($行 -split "`t", 7)
    if ($字段.Count -ne 7) {
        记录失败 "正向矩阵行不是七个字段：$行"
        continue
    }
    $编号 = $字段[0]
    $规格文件 = $字段[1]
    $行号文本 = $字段[2]
    $原文 = $字段[3]
    $方法文本 = $字段[4]
    $判定 = $字段[5]
    $理由 = $字段[6]

    检查 ($编号 -cmatch '^(C34|C5)-\d{3}$') "条款编号格式错误：$编号"
    检查 ($条款编号集合.Add($编号)) "条款编号重复：$编号"
    检查 ($规格预期.Contains($规格文件)) "矩阵引用未知规格文件：$规格文件"
    $行号 = 0
    检查 ([int]::TryParse($行号文本, [ref]$行号) -and $行号 -gt 0) "规格行号无效：$编号 / $行号文本"
    if ($规格行.ContainsKey($规格文件) -and $行号 -gt 0) {
        $范围内 = $行号 -le $规格行[$规格文件].Count
        检查 $范围内 "规格行号越界：$编号 / $($规格文件):$行号"
        if ($范围内) {
            $实际原文 = $规格行[$规格文件][$行号 - 1]
            检查 ([string]::Equals($原文, $实际原文, [System.StringComparison]::Ordinal)) "条款原文不满足 Ordinal 相等：$编号 / $($规格文件):$行号"
        }
    }
    检查 ($允许判定.Contains($判定)) "覆盖判定超出三项取值域：$编号 / $判定"
    if ($判定 -eq "不适用") {
        检查 ($允许不适用理由.Contains($理由)) "不适用理由超出四项取值域：$编号 / $理由"
    }
    $正向记录.Add([pscustomobject]@{
        编号 = $编号
        规格文件 = $规格文件
        行号 = $行号
        方法 = @(分割逗号列表 $方法文本)
        判定 = $判定
        理由 = $理由
    })
}

检查 ($正向记录.Count -eq 376) "条款总数应为 376，实际为 $($正向记录.Count)"
foreach ($规格项 in $规格预期.GetEnumerator()) {
    $前缀 = $规格项.Value.前缀
    $预期数 = $规格项.Value.条款数
    $记录 = @($正向记录 | Where-Object { $_.编号.StartsWith("$前缀-", [System.StringComparison]::Ordinal) })
    检查 ($记录.Count -eq $预期数) "$前缀 条款数应为 $预期数，实际为 $($记录.Count)"
    for ($索引 = 0; $索引 -lt $记录.Count; $索引++) {
        $预期编号 = "{0}-{1:D3}" -f $前缀, ($索引 + 1)
        检查 ($记录[$索引].编号 -ceq $预期编号) "$前缀 编号不连续：预期 $预期编号，实际 $($记录[$索引].编号)"
    }
}

$预期位置 = @{}
function 加预期位置 {
    param([string]$文件, [int[]]$行号, [int]$次数 = 1)
    foreach ($当前行号 in $行号) {
        $键 = "{0}:{1}" -f $文件, $当前行号
        检查 (-not $预期位置.ContainsKey($键)) "自验脚本的预期位置重复：$键"
        $预期位置[$键] = $次数
    }
}

$S34 = "SPEC-S3-S4-20260812.v6.md"
$S5 = "SPEC-S5-20260812.v5.md"
加预期位置 $S34 (@(17) + (19..21) + (25..40))
加预期位置 $S34 ((46..50) + (54..57) + (61..63) + (67..71))
加预期位置 $S34 ((77..80) + (84..88) + (92..93) + (97..101))
加预期位置 $S34 ((107..109) + @(113) + (117..120) + (124..125))
加预期位置 $S34 (133..139) 4
加预期位置 $S34 (@(143) + (147..154) + @(156) + (158..159) + @(161))
加预期位置 $S34 (189..193)
加预期位置 $S34 ((199..202) + @(206) + (210..212) + (216..221))
加预期位置 $S34 ((232..235) + @(239) + (243..246) + (250..254))
加预期位置 $S34 ((260..262) + @(266) + (270..272) + (276..277))
加预期位置 $S34 ((283..286) + @(290) + (294..297) + (301..302))
加预期位置 $S34 ((308..311) + @(315) + (319..322) + (326..327))
加预期位置 $S34 @(331)
加预期位置 $S34 (337..343) 6
加预期位置 $S34 ((359..367) + @(369) + (373..381))
加预期位置 $S5 (@(16) + (18..21) + @(23, 25) + (27..36))
加预期位置 $S5 ((146..154) + (158..160) + (164..168) + (172..176))
加预期位置 $S5 ((182..188) + (192..193) + (197..201) + (205..208))
加预期位置 $S5 ((214..220) + (224..225) + (229..232) + (236..239))
加预期位置 $S5 ((245..252) + (256..257) + (261..263) + (267..269))
加预期位置 $S5 (300..308) 5
加预期位置 $S5 ((316..318) + @(320) + (324..327) + (333..334) + @(336))

$实际位置 = @{}
foreach ($记录 in $正向记录) {
    $键 = "{0}:{1}" -f $记录.规格文件, $记录.行号
    if (-not $实际位置.ContainsKey($键)) {
        $实际位置[$键] = 0
    }
    $实际位置[$键]++
}
检查 ($实际位置.Count -eq $预期位置.Count) "规格条款物理行集合与机械提取清单不一致"
foreach ($键 in $预期位置.Keys) {
    检查 ($实际位置.ContainsKey($键)) "正向矩阵遗漏规格条款位置：$键"
    if ($实际位置.ContainsKey($键)) {
        检查 ($实际位置[$键] -eq $预期位置[$键]) "规格条款位置的编号次数错误：$键，预期 $($预期位置[$键])，实际 $($实际位置[$键])"
    }
}
foreach ($键 in $实际位置.Keys) {
    检查 ($预期位置.ContainsKey($键)) "正向矩阵出现范围外规格位置：$键"
}

function 检查迁移表坐标 {
    param([string]$文件, [int[]]$行号, [string[]]$起始状态)
    foreach ($当前行号 in $行号) {
        $原文单元 = @(
            $规格行[$文件][$当前行号 - 1].Trim().Trim([char]'|').Split('|') |
                ForEach-Object { $_.Trim() }
        )
        $记录 = @(
            $正向记录 |
                Where-Object { $_.规格文件 -ceq $文件 -and $_.行号 -eq $当前行号 }
        )
        检查 ($记录.Count -eq $起始状态.Count) "迁移表单元格数量错误：$($文件):$当前行号"
        for ($索引 = 0; $索引 -lt [Math]::Min($记录.Count, $起始状态.Count); $索引++) {
            $坐标片段 = "起始状态" + [char]0x201C + $起始状态[$索引] + [char]0x201D
            检查 ($记录[$索引].理由.Contains($坐标片段)) "迁移表单元格坐标错误：$($记录[$索引].编号)"
            $预期类型 = if ($原文单元[$索引 + 1].StartsWith("不可达", [System.StringComparison]::Ordinal)) {
                "断言型条款"
            }
            else {
                "可达单元格"
            }
            检查 ($记录[$索引].理由.StartsWith($预期类型, [System.StringComparison]::Ordinal)) "迁移表断言类型错误：$($记录[$索引].编号)"
        }
    }
}

检查迁移表坐标 $S34 (133..139) @("页面外", "S3-1 扫描中", "S3-2 就绪", "S3-4 空集")
检查迁移表坐标 $S34 (337..343) @("S3-2 外部源", "S4-1 已提交", "S4-2 已恢复交互", "S4-E1 全批成功", "S4-E2 整批失败", "S4-E3 结果未知")
检查迁移表坐标 $S5 (300..308) @("外部源", "S5-T0", "S5-C", "S5-F", "S5-U")

$测试方法 = @{}
$项目根前缀 = $项目根.TrimEnd('\') + '\'
foreach ($文件 in Get-ChildItem -LiteralPath $测试根 -Filter "*.swift" -File -Recurse | Sort-Object FullName) {
    $相对路径 = $文件.FullName.Substring($项目根前缀.Length).Replace('\', '/')
    $行数组 = @(Get-Content -LiteralPath $文件.FullName -Encoding UTF8)
    for ($索引 = 0; $索引 -lt $行数组.Count; $索引++) {
        if ($行数组[$索引] -cmatch '^\s*func\s+(test[A-Za-z0-9_]+)\s*\(') {
            $名称 = $Matches[1]
            检查 (-not $测试方法.ContainsKey($名称)) "测试方法名重复：$名称"
            if (-not $测试方法.ContainsKey($名称)) {
                $测试方法[$名称] = [pscustomobject]@{
                    文件 = $相对路径
                    行号 = $索引 + 1
                }
            }
        }
    }
}
检查 ($测试方法.Count -eq 149) "XCTest 方法静态计数应为 149，实际为 $($测试方法.Count)"

$正向映射对 = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($记录 in $正向记录) {
    foreach ($方法名 in $记录.方法) {
        检查 ($测试方法.ContainsKey($方法名)) "正向矩阵引用不存在的 XCTest 方法：$($记录.编号) / $方法名"
        检查 ($正向映射对.Add("$方法名`t$($记录.编号)")) "正向矩阵重复映射：$方法名 / $($记录.编号)"
    }
}

$反向区间 = 取标记区间 $报告行 "<!-- 反向映射开始 -->" "<!-- 反向映射结束 -->"
$反向数据行 = @(
    $反向区间 |
        Where-Object { $_ -ne '```' -and -not $_.StartsWith("XCTest 方法名`t", [System.StringComparison]::Ordinal) }
)
$反向方法集合 = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$反向映射对 = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$反向命中 = @{}
foreach ($行 in $反向数据行) {
    $字段 = @($行 -split "`t", 4)
    if ($字段.Count -ne 4) {
        记录失败 "反向映射行不是四个字段：$行"
        continue
    }
    $方法名 = $字段[0]
    $文件 = $字段[1]
    $行号 = 0
    $条款列表 = @(分割逗号列表 $字段[3])
    检查 ($反向方法集合.Add($方法名)) "反向映射重复列出 XCTest 方法：$方法名"
    检查 ($测试方法.ContainsKey($方法名)) "反向映射引用不存在的 XCTest 方法：$方法名"
    检查 ([int]::TryParse($字段[2], [ref]$行号) -and $行号 -gt 0) "反向映射测试行号无效：$方法名"
    if ($测试方法.ContainsKey($方法名)) {
        检查 ($文件 -ceq $测试方法[$方法名].文件) "反向映射测试文件不匹配：$方法名"
        检查 ($行号 -eq $测试方法[$方法名].行号) "反向映射测试行号不匹配：$方法名"
    }
    foreach ($条款编号 in $条款列表) {
        检查 ($条款编号集合.Contains($条款编号)) "反向映射引用不存在的条款：$方法名 / $条款编号"
        检查 ($反向映射对.Add("$方法名`t$条款编号")) "反向映射重复：$方法名 / $条款编号"
    }
    $反向命中[$方法名] = $条款列表
}
检查 ($反向方法集合.Count -eq 149) "反向映射应列出 149 个方法，实际为 $($反向方法集合.Count)"
foreach ($方法名 in $测试方法.Keys) {
    检查 ($反向方法集合.Contains($方法名)) "反向映射遗漏 XCTest 方法：$方法名"
}
foreach ($映射对 in $正向映射对) {
    检查 ($反向映射对.Contains($映射对)) "正向映射未出现在反向映射：$映射对"
}
foreach ($映射对 in $反向映射对) {
    检查 ($正向映射对.Contains($映射对)) "反向映射未出现在正向映射：$映射对"
}

$未覆盖预期 = @($正向记录 | Where-Object { $_.判定 -eq "未覆盖" })
$不适用预期 = @($正向记录 | Where-Object { $_.判定 -eq "不适用" })
$未覆盖实际 = 解析三列汇总表 (取标记区间 $报告行 "<!-- 未覆盖清单开始 -->" "<!-- 未覆盖清单结束 -->")
$不适用实际 = 解析三列汇总表 (取标记区间 $报告行 "<!-- 不适用清单开始 -->" "<!-- 不适用清单结束 -->")
检查 ($未覆盖实际.Count -eq $未覆盖预期.Count) "未覆盖清单数量与正向矩阵不一致"
检查 ($不适用实际.Count -eq $不适用预期.Count) "不适用清单数量与正向矩阵不一致"
foreach ($记录 in $未覆盖预期) {
    检查 ($未覆盖实际.ContainsKey($记录.编号)) "未覆盖清单遗漏：$($记录.编号)"
    if ($未覆盖实际.ContainsKey($记录.编号)) {
        检查 ($未覆盖实际[$记录.编号] -ceq $记录.理由) "未覆盖清单理由不一致：$($记录.编号)"
    }
}
foreach ($记录 in $不适用预期) {
    检查 ($不适用实际.ContainsKey($记录.编号)) "不适用清单遗漏：$($记录.编号)"
    if ($不适用实际.ContainsKey($记录.编号)) {
        检查 ($不适用实际[$记录.编号] -ceq $记录.理由) "不适用清单理由不一致：$($记录.编号)"
    }
}

$未命中预期 = @(
    $测试方法.Keys |
        Where-Object { -not $反向命中.ContainsKey($_) -or $反向命中[$_].Count -eq 0 }
)
$未命中实际 = 解析两列测试表 (取标记区间 $报告行 "<!-- 未命中测试清单开始 -->" "<!-- 未命中测试清单结束 -->")
检查 ($未命中实际.Count -eq $未命中预期.Count) "未命中测试清单数量与反向映射不一致"
foreach ($方法名 in $未命中预期) {
    检查 ($未命中实际.ContainsKey($方法名)) "未命中测试清单遗漏：$方法名"
}

$已覆盖数 = @($正向记录 | Where-Object { $_.判定 -eq "已覆盖" }).Count
$未覆盖数 = $未覆盖预期.Count
$不适用数 = $不适用预期.Count
检查 ($已覆盖数 -eq 192) "已覆盖数应为 192，实际为 $已覆盖数"
检查 ($未覆盖数 -eq 165) "未覆盖数应为 165，实际为 $未覆盖数"
检查 ($不适用数 -eq 19) "不适用数应为 19，实际为 $不适用数"
检查 ($未命中预期.Count -eq 8) "未命中测试数应为 8，实际为 $($未命中预期.Count)"
$报告全文 = $报告行 -join "`n"
检查 ($报告全文 -cmatch '\| 条款总数 \| 376 \|') "报告汇总条款总数不匹配"
检查 ($报告全文 -cmatch '\| 已覆盖 \| 192 \|') "报告汇总已覆盖数不匹配"
检查 ($报告全文 -cmatch '\| 未覆盖 \| 165 \|') "报告汇总未覆盖数不匹配"
检查 ($报告全文 -cmatch '\| 不适用 \| 19 \|') "报告汇总不适用数不匹配"

Push-Location $项目根
try {
    $基线存在 = (& git cat-file -t $基线 2>$null) -eq "commit"
    检查 $基线存在 "Git 中不存在基线提交：$基线"
    if ($基线存在) {
        $基线文件 = @{}
        $树输出 = @(& git ls-tree -r $基线 -- PhotoCleanupMVE PhotoCleanupMVETests)
        检查 ($LASTEXITCODE -eq 0) "无法读取基线产品与测试 Git 树"
        foreach ($行 in $树输出) {
            if ($行 -cmatch '^\d+\s+blob\s+([0-9a-f]{40})\t(.+)$') {
                $基线文件[$Matches[2]] = $Matches[1]
            }
            else {
                记录失败 "无法解析基线 Git 树条目：$行"
            }
        }

        $当前文件 = @{}
        foreach ($目录名 in @("PhotoCleanupMVE", "PhotoCleanupMVETests")) {
            foreach ($文件 in Get-ChildItem -LiteralPath (Join-Path $项目根 $目录名) -File -Recurse) {
                $相对路径 = $文件.FullName.Substring($项目根前缀.Length).Replace('\', '/')
                $当前文件[$相对路径] = $文件.FullName
            }
        }
        检查 ($当前文件.Count -eq $基线文件.Count) "产品与测试文件数量相对基线变化"
        foreach ($相对路径 in $基线文件.Keys) {
            检查 ($当前文件.ContainsKey($相对路径)) "产品或测试文件相对基线缺失：$相对路径"
            if ($当前文件.ContainsKey($相对路径)) {
                $实际对象 = (& git hash-object "--path=$相对路径" -- $相对路径).Trim()
                检查 ($LASTEXITCODE -eq 0) "无法计算当前 Git blob：$相对路径"
                检查 ($实际对象 -ceq $基线文件[$相对路径]) "产品或测试 Git blob 相对基线变化：$相对路径"
            }
        }
        foreach ($相对路径 in $当前文件.Keys) {
            检查 ($基线文件.ContainsKey($相对路径)) "产品或测试目录新增文件：$相对路径"
        }
    }
}
finally {
    Pop-Location
}

if ($失败清单.Count -gt 0) {
    Write-Host "自验失败：共执行 $检查总数 项检查，失败 $($失败清单.Count) 项。" -ForegroundColor Red
    foreach ($失败项 in $失败清单) {
        Write-Host "  - $失败项" -ForegroundColor Red
    }
    exit 1
}

Write-Host "自验通过：共执行 $检查总数 项检查；376 条条款、149 个 XCTest 方法、正反映射、三张汇总表、规格摘要及基线 Git blob 全部符合要求。" -ForegroundColor Green
Write-Host "统计：已覆盖 192，未覆盖 165，不适用 19，未命中测试 8。"
