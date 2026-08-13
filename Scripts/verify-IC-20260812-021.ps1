param(
    [switch]$写入矩阵
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$项目根 = Split-Path -Parent $PSScriptRoot
$工作区 = Split-Path -Parent $项目根
$测试根 = Join-Path $项目根 "PhotoCleanupMVETests"
$矩阵路径 = Join-Path $项目根 "Reports/TRACEABILITY-S3-S5.md"
$自验报告路径 = Join-Path $项目根 "Reports/IC-20260812-021-SELF-VERIFICATION.md"
$旧矩阵提交 = "c7ed4b18c579fd6d2904ea856dcac404906e2ec0"
$旧矩阵对象 = "a3dcdb21a5932c32de01938bb18b60d432404083"
$实现提交 = "01ebf8263d20a58340aedd78be98cadd06d30eb0"
$失败清单 = [System.Collections.Generic.List[string]]::new()
$检查总数 = 0

function 记录失败 {
    param([string]$消息)
    $script:失败清单.Add($消息)
}

function 检查 {
    param([bool]$条件, [string]$失败消息)
    $script:检查总数++
    if (-not $条件) {
        记录失败 $失败消息
    }
}

function 规范化文本 {
    param([string]$文本)
    return $文本.Replace("`r`n", "`n").TrimEnd() + "`n"
}

function 分割逗号列表 {
    param([string]$文本)
    if ([string]::IsNullOrWhiteSpace($文本) -or $文本 -ceq "—") {
        return @()
    }
    return @($文本 -split ",\s*" | Where-Object { $_ })
}

function 取标记区间 {
    param(
        [string[]]$行,
        [string]$开始标记,
        [string]$结束标记
    )
    $开始 = [Array]::IndexOf($行, $开始标记)
    $结束 = [Array]::IndexOf($行, $结束标记)
    if ($开始 -lt 0 -or $结束 -le $开始) {
        记录失败 "缺少或错置标记：$开始标记 / $结束标记"
        return @()
    }
    return @($行[($开始 + 1)..($结束 - 1)])
}

function 解析正向记录 {
    param([string]$矩阵文本)

    $全部行 = @($矩阵文本 -split "\r?\n")
    $区间 = 取标记区间 $全部行 "<!-- 正向矩阵开始 -->" "<!-- 正向矩阵结束 -->"
    $结果 = [System.Collections.Generic.List[object]]::new()
    foreach ($行 in $区间) {
        if ($行 -eq '```' -or $行.StartsWith("条款编号`t", [System.StringComparison]::Ordinal)) {
            continue
        }
        $字段 = @($行 -split "`t", 7)
        if ($字段.Count -ne 7) {
            记录失败 "正向矩阵行不是七个字段：$行"
            continue
        }
        $方法 = [System.Collections.Generic.List[string]]::new()
        foreach ($名称 in 分割逗号列表 $字段[4]) {
            $方法.Add($名称)
        }
        $迁移类型 = ""
        $事件 = ""
        $起始状态 = ""
        if ($字段[6] -cmatch '^(可达单元格|断言型条款)（事件“(.+)” × 起始状态“([^”]+)”）') {
            $迁移类型 = $Matches[1]
            $事件 = $Matches[2]
            $起始状态 = $Matches[3]
        }
        $行号 = 0
        if (-not [int]::TryParse($字段[2], [ref]$行号)) {
            记录失败 "规格行号不是整数：$($字段[0]) / $($字段[2])"
        }
        $结果.Add([pscustomobject]@{
            编号 = $字段[0]
            规格文件 = $字段[1]
            行号 = $行号
            原文 = $字段[3]
            方法 = $方法
            判定 = $字段[5]
            理由 = $字段[6]
            迁移类型 = $迁移类型
            事件 = $事件
            起始状态 = $起始状态
        })
    }
    return @($结果)
}

function 添加方法映射 {
    param(
        [object]$记录,
        [string]$方法名
    )
    if (-not $记录.方法.Contains($方法名)) {
        $记录.方法.Add($方法名)
    }
}

function 坐标前缀 {
    param([object]$记录)
    if ([string]::IsNullOrEmpty($记录.迁移类型)) {
        return ""
    }
    return ('{0}（事件“{1}” × 起始状态“{2}”）' -f $记录.迁移类型, $记录.事件, $记录.起始状态)
}

function 带坐标理由 {
    param(
        [object]$记录,
        [string]$理由
    )
    $前缀 = 坐标前缀 $记录
    if ([string]::IsNullOrEmpty($前缀)) {
        return $理由
    }
    return "${前缀}：$理由"
}

function 取理由类别 {
    param([object]$记录)
    $前缀 = 坐标前缀 $记录
    if ([string]::IsNullOrEmpty($前缀)) {
        return $记录.理由
    }
    $带分隔符 = "${前缀}："
    if ($记录.理由.StartsWith($带分隔符, [System.StringComparison]::Ordinal)) {
        return $记录.理由.Substring($带分隔符.Length)
    }
    return $记录.理由
}

function 集合相同 {
    param(
        [string[]]$左,
        [string[]]$右
    )
    $左集合 = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    $右集合 = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($值 in $左) {
        [void]$左集合.Add($值)
    }
    foreach ($值 in $右) {
        [void]$右集合.Add($值)
    }
    return $左集合.SetEquals($右集合)
}

function 生成矩阵文本 {
    param(
        [object[]]$正向记录,
        [hashtable]$测试方法
    )

    $输出 = [System.Collections.Generic.List[string]]::new()
    $已覆盖数 = @($正向记录 | Where-Object { $_.判定 -ceq "已覆盖" }).Count
    $未覆盖记录 = @($正向记录 | Where-Object { $_.判定 -ceq "未覆盖" })
    $不适用记录 = @($正向记录 | Where-Object { $_.判定 -ceq "不适用" })
    $方法顺序 = @(
        $测试方法.Values |
            Sort-Object 文件, 行号 |
            ForEach-Object { $_.名称 }
    )
    $反向映射 = @{}
    foreach ($方法名 in $方法顺序) {
        $反向映射[$方法名] = [System.Collections.Generic.List[string]]::new()
    }
    foreach ($记录 in $正向记录) {
        foreach ($方法名 in $记录.方法) {
            if ($反向映射.ContainsKey($方法名)) {
                $反向映射[$方法名].Add($记录.编号)
            }
        }
    }
    $未命中方法 = @($方法顺序 | Where-Object { $反向映射[$_].Count -eq 0 })

    $输出.Add("# SPEC-S3-S5 XCTest 可追溯矩阵")
    $输出.Add("")
    $输出.Add("## 一、范围与判定口径")
    $输出.Add("")
    $输出.Add("- 任务：``IC-20260812-021-traceability-rerun``；当前产品与测试证据基线：``$旧矩阵提交``；上游受验实现提交：``$实现提交``。")
    $输出.Add("- 输入规格：``SPEC-S3-S4-20260812.v6.md`` 与 ``SPEC-S5-20260812.v5.md``；沿用 IC-20260812-011 的机械提取范围、七个正向字段和四个反向字段。")
    $输出.Add("- 状态迁移表仍按数据单元格编号；单元格坐标与可达/不可达标记保留在判定理由开头，供 ``TransitionTableGuardTests`` 在运行时读取。")
    $输出.Add('- 方法列只列直接相关的 XCTest 断言。若方法只覆盖复合条款的一部分，仍记录方法，但覆盖判定保守取“未覆盖”。')
    $输出.Add("- ``不适用`` 理由共五类：``MVE 范围外``、``该条款为未定项阻断``、``该条款为纯文案``、``该条款为纯视觉``、``实现约束比规格更强，该路径在当前实现下不可达``。")
    $输出.Add('- MVE 范围外的机械口径：条款依赖本工程尚未实现的 S1、S2、上游整理页、清理入口页或照片列表页时，判为“不适用：MVE 范围外”，不判“未覆盖”。')
    $输出.Add("- 一致性闸门：候选矩阵写入前，先与 ``$旧矩阵提交`` 中的旧矩阵比较 115 个迁移坐标集合及不可达标记集合；任一集合不同均停止且不覆盖现有矩阵。")
    $输出.Add("")
    $输出.Add("## 二、汇总")
    $输出.Add("")
    $输出.Add("| 指标 | 数量 |")
    $输出.Add("|---|---:|")
    $输出.Add("| 条款总数 | $($正向记录.Count) |")
    $输出.Add("| 已覆盖 | $已覆盖数 |")
    $输出.Add("| 未覆盖 | $($未覆盖记录.Count) |")
    $输出.Add("| 不适用 | $($不适用记录.Count) |")
    $输出.Add("| 第五类不适用 | $(@($不适用记录 | Where-Object { (取理由类别 $_) -ceq '实现约束比规格更强，该路径在当前实现下不可达' }).Count) |")
    $输出.Add("| XCTest 方法总数 | $($测试方法.Count) |")
    $输出.Add("| 未命中测试 | $($未命中方法.Count) |")
    $输出.Add("")
    $输出.Add("## 三、正向矩阵")
    $输出.Add("")
    $输出.Add("以下为制表符分隔表；每条条款严格占一行。")
    $输出.Add("")
    $输出.Add("<!-- 正向矩阵开始 -->")
    $输出.Add('```')
    $输出.Add("条款编号`t规格文件`t行号`t条款原文（逐字，不改写）`t对应 XCTest 方法名（可多个，无则留空）`t覆盖判定`t判定理由")
    foreach ($记录 in $正向记录) {
        $方法文本 = $记录.方法 -join ", "
        $输出.Add((
            "$($记录.编号)`t$($记录.规格文件)`t$($记录.行号)`t" +
            "$($记录.原文)`t$方法文本`t$($记录.判定)`t$($记录.理由)"
        ))
    }
    $输出.Add('```')
    $输出.Add("<!-- 正向矩阵结束 -->")
    $输出.Add("")
    $输出.Add("## 四、反向映射")
    $输出.Add("")
    $输出.Add("<!-- 反向映射开始 -->")
    $输出.Add('```')
    $输出.Add("XCTest 方法名`t测试文件`t行号`t命中条款编号")
    foreach ($方法名 in $方法顺序) {
        $信息 = $测试方法[$方法名]
        $条款文本 = if ($反向映射[$方法名].Count -eq 0) {
            "—"
        }
        else {
            $反向映射[$方法名] -join ", "
        }
        $输出.Add("$方法名`t$($信息.文件)`t$($信息.行号)`t$条款文本")
    }
    $输出.Add('```')
    $输出.Add("<!-- 反向映射结束 -->")
    $输出.Add("")
    $输出.Add("## 五、未覆盖清单")
    $输出.Add("")
    $输出.Add("<!-- 未覆盖清单开始 -->")
    $输出.Add("| 条款编号 | 规格位置 | 判定理由 |")
    $输出.Add("|---|---|---|")
    foreach ($记录 in $未覆盖记录) {
        $输出.Add(('| {0} | `{1}:{2}` | {3} |' -f $记录.编号, $记录.规格文件, $记录.行号, $记录.理由))
    }
    $输出.Add("<!-- 未覆盖清单结束 -->")
    $输出.Add("")
    $输出.Add("## 六、不适用清单")
    $输出.Add("")
    $输出.Add("<!-- 不适用清单开始 -->")
    $输出.Add("| 条款编号 | 规格位置 | 判定理由 |")
    $输出.Add("|---|---|---|")
    foreach ($记录 in $不适用记录) {
        $输出.Add(('| {0} | `{1}:{2}` | {3} |' -f $记录.编号, $记录.规格文件, $记录.行号, $记录.理由))
    }
    $输出.Add("<!-- 不适用清单结束 -->")
    $输出.Add("")
    $输出.Add("## 七、未命中测试清单")
    $输出.Add("")
    $输出.Add("<!-- 未命中测试清单开始 -->")
    $输出.Add("| XCTest 方法名 | 测试位置 |")
    $输出.Add("|---|---|")
    foreach ($方法名 in $未命中方法) {
        $信息 = $测试方法[$方法名]
        $输出.Add(('| `{0}` | `{1}:{2}` |' -f $方法名, $信息.文件, $信息.行号))
    }
    $输出.Add("<!-- 未命中测试清单结束 -->")
    $输出.Add("")
    return [string]::Join("`n", $输出)
}

Write-Host "运行通用结构门禁……"
& (Join-Path $PSScriptRoot "selfcheck.ps1")
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Push-Location $项目根
try {
    $旧提交类型 = (& git cat-file -t $旧矩阵提交 2>$null)
    检查 ($旧提交类型 -ceq "commit") "Git 中不存在重跑前矩阵提交：$旧矩阵提交"
    $旧对象实际 = (& git rev-parse "${旧矩阵提交}:Reports/TRACEABILITY-S3-S5.md" 2>$null).Trim()
    检查 ($LASTEXITCODE -eq 0 -and $旧对象实际 -ceq $旧矩阵对象) "重跑前矩阵 Git blob 不匹配"
    & git merge-base --is-ancestor $实现提交 $旧矩阵提交
    检查 ($LASTEXITCODE -eq 0) "IC-20260812-019 受验实现提交不是重跑基线祖先"
    $旧矩阵文本 = @(& git show "${旧矩阵提交}:Reports/TRACEABILITY-S3-S5.md") -join "`n"
    检查 ($LASTEXITCODE -eq 0) "无法读取重跑前矩阵"
}
finally {
    Pop-Location
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
    if (Test-Path -LiteralPath $信息.路径 -PathType Leaf) {
        $实际摘要 = (Get-FileHash -LiteralPath $信息.路径 -Algorithm SHA256).Hash
        检查 ($实际摘要 -ceq $信息.摘要) "输入规格摘要不匹配：$($规格项.Key)"
        $规格行[$规格项.Key] = @(Get-Content -LiteralPath $信息.路径 -Encoding UTF8)
    }
    else {
        Write-Host "提示：当前环境没有仓库外规格 $($规格项.Key)，改用旧矩阵 Git blob 与 IC-011 摘要证据链。"
        Push-Location $项目根
        try {
            $旧报告 = @(& git show "${旧矩阵提交}:Reports/IC-20260812-011-SELF-VERIFICATION.md") -join "`n"
            检查 ($LASTEXITCODE -eq 0) "无法读取 IC-011 自验报告"
            检查 ($旧报告.Contains($信息.摘要)) "IC-011 自验报告缺少规格摘要：$($规格项.Key)"
        }
        finally {
            Pop-Location
        }
    }
}

$正向记录 = @(解析正向记录 $旧矩阵文本)
$编号集合 = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
检查 ($正向记录.Count -eq 376) "旧矩阵条款总数应为 376，实际为 $($正向记录.Count)"
foreach ($规格项 in $规格预期.GetEnumerator()) {
    $前缀 = $规格项.Value.前缀
    $记录组 = @($正向记录 | Where-Object { $_.编号.StartsWith("$前缀-", [System.StringComparison]::Ordinal) })
    检查 ($记录组.Count -eq $规格项.Value.条款数) "$前缀 条款数应为 $($规格项.Value.条款数)，实际为 $($记录组.Count)"
    for ($索引 = 0; $索引 -lt $记录组.Count; $索引++) {
        $预期编号 = "{0}-{1:D3}" -f $前缀, ($索引 + 1)
        检查 ($记录组[$索引].编号 -ceq $预期编号) "$前缀 编号不连续：预期 $预期编号，实际 $($记录组[$索引].编号)"
    }
}
foreach ($记录 in $正向记录) {
    检查 ($编号集合.Add($记录.编号)) "条款编号重复：$($记录.编号)"
    检查 ($规格预期.Contains($记录.规格文件)) "矩阵引用未知规格：$($记录.编号) / $($记录.规格文件)"
    if ($规格行.ContainsKey($记录.规格文件)) {
        $行号有效 = $记录.行号 -gt 0 -and $记录.行号 -le $规格行[$记录.规格文件].Count
        检查 $行号有效 "规格行号越界：$($记录.编号) / $($记录.规格文件):$($记录.行号)"
        if ($行号有效) {
            检查 (
                [string]::Equals(
                    $记录.原文,
                    $规格行[$记录.规格文件][$记录.行号 - 1],
                    [System.StringComparison]::Ordinal
                )
            ) "条款原文不满足 Ordinal 相等：$($记录.编号)"
        }
    }
}

$测试方法 = @{}
$项目根前缀 = $项目根.TrimEnd([char]'\', [char]'/') + [System.IO.Path]::DirectorySeparatorChar
foreach ($文件 in Get-ChildItem -LiteralPath $测试根 -Filter "*.swift" -File -Recurse | Sort-Object FullName) {
    $相对路径 = $文件.FullName.Substring($项目根前缀.Length).Replace([char]'\', [char]'/')
    $行数组 = @(Get-Content -LiteralPath $文件.FullName -Encoding UTF8)
    for ($索引 = 0; $索引 -lt $行数组.Count; $索引++) {
        if ($行数组[$索引] -cmatch '^\s*func\s+(test[A-Za-z0-9_]+)\s*\(') {
            $名称 = $Matches[1]
            检查 (-not $测试方法.ContainsKey($名称)) "XCTest 方法名重复：$名称"
            if (-not $测试方法.ContainsKey($名称)) {
                $测试方法[$名称] = [pscustomobject]@{
                    名称 = $名称
                    文件 = $相对路径
                    行号 = $索引 + 1
                }
            }
        }
    }
}
检查 ($测试方法.Count -eq 179) "XCTest 静态总数应为 179，实际为 $($测试方法.Count)"

$新增直接映射 = @{}
foreach ($方法名 in $测试方法.Keys) {
    if ($方法名 -cmatch '^test(C(?:34|5)_\d{3})') {
        $条款编号 = $Matches[1].Replace('_', '-')
        检查 ($编号集合.Contains($条款编号)) "带编号测试引用未知条款：$方法名 / $条款编号"
        if (-not $新增直接映射.ContainsKey($条款编号)) {
            $新增直接映射[$条款编号] = [System.Collections.Generic.List[string]]::new()
        }
        $新增直接映射[$条款编号].Add($方法名)
    }
}
检查 ($新增直接映射.Count -eq 29) "带条款编号的专项测试应命中 29 个唯一条款，实际为 $($新增直接映射.Count)"
foreach ($记录 in $正向记录) {
    if ($新增直接映射.ContainsKey($记录.编号)) {
        foreach ($方法名 in $新增直接映射[$记录.编号]) {
            添加方法映射 $记录 $方法名
        }
    }
}

$守卫方法 = "testAll115TransitionCellsAndEveryUnreachableCombination"
检查 ($测试方法.ContainsKey($守卫方法)) "缺少迁移表守卫测试方法"
$守卫路径 = Join-Path $测试根 "TransitionTableGuardTests.swift"
$守卫文本 = Get-Content -LiteralPath $守卫路径 -Raw -Encoding UTF8
foreach ($片段 in @(
    "loadTransitionCells()",
    "for cell in cells",
    "guard cell.isUnreachable else",
    "Bundle(for: Self.self).url",
    "XCTAssertEqual(cells.count, 115,",
    "XCTAssertEqual(cells.filter(\.isUnreachable).count, 63,"
)) {
    检查 ($守卫文本.Contains($片段)) "迁移守卫缺少证据片段：$片段"
}
检查 (-not ($守卫文本 -cmatch 'TransitionCell\s*\(\s*clauseID:\s*"C(?:34|5)-')) "迁移守卫手工重录了条款坐标"
foreach ($记录 in $正向记录 | Where-Object { $_.迁移类型 -ceq "断言型条款" }) {
    添加方法映射 $记录 $守卫方法
}

$S3路径 = Join-Path $项目根 "PhotoCleanupMVE/Core/S3StateMachine.swift"
$S4路径 = Join-Path $项目根 "PhotoCleanupMVE/Core/S4StateMachine.swift"
$协调器路径 = Join-Path $项目根 "PhotoCleanupMVE/App/CleanupCoordinator.swift"
$S3视图路径 = Join-Path $项目根 "PhotoCleanupMVE/Features/S3/S3View.swift"
$S4测试路径 = Join-Path $测试根 "S4StateMachineTests.swift"
$S3文本 = Get-Content -LiteralPath $S3路径 -Raw -Encoding UTF8
$S4文本 = Get-Content -LiteralPath $S4路径 -Raw -Encoding UTF8
$协调器文本 = Get-Content -LiteralPath $协调器路径 -Raw -Encoding UTF8
$S3视图文本 = Get-Content -LiteralPath $S3视图路径 -Raw -Encoding UTF8
$S4测试文本 = Get-Content -LiteralPath $S4测试路径 -Raw -Encoding UTF8

$强约束证据 = @(
    $S3文本.Contains("private(set) var assets:"),
    $S3文本.Contains("private(set) var conclusionCache:"),
    $S3文本.Contains("private(set) var state:"),
    $S3文本.Contains("private(set) var frozenSnapshot:"),
    ($S3文本 -cmatch 'var\s+canSubmit:\s*Bool\s*\{\s*state\s*==\s*\.ready\s*&&\s*frozenSnapshot\s*==\s*nil\s*\}'),
    ([regex]::Matches($S3文本, 'normalizeStateAndEnqueueIfNeeded\(\)').Count -eq 8),
    $S3文本.Contains("state = isScanComplete ? .ready : .scanning"),
    $S3文本.Contains("guard !assets.isEmpty, isScanComplete else"),
    $S4文本.Contains("guard case let .frozen(snapshot) = submissionSource.freezeSubmissionSnapshot() else"),
    $协调器文本.Contains("from: machine,"),
    $S3视图文本.Contains(".disabled(!machine.canSubmit)"),
    $S4测试文本.Contains("testC34_104FreezeFailureDoesNotCallDeletionService"),
    $S4测试文本.Contains("XCTAssertEqual(deletionService.startDeletionCallCount, 0)")
)
for ($索引 = 0; $索引 -lt $强约束证据.Count; $索引++) {
    检查 $强约束证据[$索引] "实现强约束证据第 $($索引 + 1) 项不成立"
}
$强约束证据成立 = -not ($强约束证据 -contains $false)
$第五类编号 = [System.Collections.Generic.List[string]]::new()
if ($强约束证据成立) {
    foreach ($记录 in $正向记录) {
        $普通失败条款 = [string]::IsNullOrEmpty($记录.迁移类型) -and
            $记录.原文.Contains("点击提交时快照冻结校验失败")
        $就绪单元格失败分支 = $记录.迁移类型 -ceq "可达单元格" -and
            $记录.事件 -ceq "点击提交" -and
            $记录.起始状态 -ceq "S3-2 就绪" -and
            $记录.原文.Contains("校验失败")
        if ($普通失败条款 -or $就绪单元格失败分支) {
            $第五类编号.Add($记录.编号)
        }
    }
}
检查 ($第五类编号.Count -eq 2) "实现强约束证据应机械命中 2 条，实际为 $($第五类编号.Count)"
检查 (集合相同 @($第五类编号) @("C34-052", "C34-090")) "实现强约束证据命中的条款集合不符合题卡指示"

$README路径 = Join-Path $项目根 "README.md"
$未定项路径 = Join-Path $项目根 "Reports/UNDECIDED-ITEMS.md"
$README文本 = Get-Content -LiteralPath $README路径 -Raw -Encoding UTF8
$未定项文本 = Get-Content -LiteralPath $未定项路径 -Raw -Encoding UTF8
$功能目录 = @(
    Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVE/Features") -Directory |
        ForEach-Object { $_.Name } |
        Sort-Object
)
检查 ($README文本.Contains("工程不包含 S1、S2")) "README 未声明 S1、S2 不在工程内"
检查 ($未定项文本.Contains("S3 返回上游与 S5 外部出口的内部页面")) "未定项报告缺少外部页面范围证据"
检查 ($未定项文本.Contains("外部页面保持未实现")) "未定项报告未声明外部页面保持未实现"
检查 (($功能目录 -join ",") -ceq "S3,S4,S5,Shared") "功能目录出现范围外页面：$($功能目录 -join ', ')"

$MVE范围外编号 = [System.Collections.Generic.List[string]]::new()
foreach ($记录 in $正向记录) {
    $依赖上游页 = [string]::IsNullOrEmpty($记录.迁移类型) -and
        $记录.原文.Contains("上游整理页")
    $依赖照片列表页 = [string]::IsNullOrEmpty($记录.迁移类型) -and
        $记录.原文.Contains("照片列表")
    $依赖清理入口页 = [string]::IsNullOrEmpty($记录.迁移类型) -and
        $记录.原文.Contains("S5-EXIT") -and
        ($记录.原文.Contains("定义外部出口") -or $记录.原文.Contains("即应用的清理入口页"))
    $迁移至清理入口页 = $记录.迁移类型 -ceq "可达单元格" -and
        $记录.事件 -ceq "用户离开页面" -and
        @("S5-T0", "S5-U") -ccontains $记录.起始状态
    if ($依赖上游页 -or $依赖照片列表页 -or $依赖清理入口页 -or $迁移至清理入口页) {
        $MVE范围外编号.Add($记录.编号)
    }
}
检查 ($MVE范围外编号.Count -eq 18) "MVE 范围外规则应机械命中 18 条，实际为 $($MVE范围外编号.Count)"

foreach ($记录 in $正向记录) {
    if ($MVE范围外编号.Contains($记录.编号)) {
        $记录.判定 = "不适用"
        $记录.理由 = 带坐标理由 $记录 "MVE 范围外"
    }
    elseif ($第五类编号.Contains($记录.编号)) {
        $记录.判定 = "不适用"
        $记录.理由 = 带坐标理由 $记录 "实现约束比规格更强，该路径在当前实现下不可达"
    }
    elseif ($记录.迁移类型 -ceq "断言型条款") {
        $记录.判定 = "已覆盖"
        $记录.理由 = 带坐标理由 $记录 "守卫测试在运行时读取本矩阵坐标并直接断言该不可达组合。"
    }
    elseif ($新增直接映射.ContainsKey($记录.编号)) {
        $记录.判定 = "已覆盖"
        $记录.理由 = 带坐标理由 $记录 "所列专项方法直接断言该条款。"
    }
}

$允许判定 = @("已覆盖", "未覆盖", "不适用")
$允许不适用理由 = @(
    "MVE 范围外",
    "该条款为未定项阻断",
    "该条款为纯文案",
    "该条款为纯视觉",
    "实现约束比规格更强，该路径在当前实现下不可达"
)
$正向映射对 = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($记录 in $正向记录) {
    检查 ($允许判定 -ccontains $记录.判定) "覆盖判定超出取值域：$($记录.编号) / $($记录.判定)"
    if ($记录.判定 -ceq "不适用") {
        检查 ($允许不适用理由 -ccontains (取理由类别 $记录)) "不适用理由超出五类取值域：$($记录.编号) / $($记录.理由)"
    }
    foreach ($方法名 in $记录.方法) {
        检查 ($测试方法.ContainsKey($方法名)) "矩阵引用不存在的 XCTest 方法：$($记录.编号) / $方法名"
        检查 ($正向映射对.Add("$方法名`t$($记录.编号)")) "正向矩阵重复映射：$方法名 / $($记录.编号)"
    }
}

$旧迁移 = @($正向记录 | Where-Object { -not [string]::IsNullOrEmpty($_.迁移类型) })
$候选迁移 = @($正向记录 | Where-Object { -not [string]::IsNullOrEmpty($_.迁移类型) })
$旧坐标 = @($旧迁移 | ForEach-Object { "$($_.规格文件)|$($_.事件)|$($_.起始状态)" })
$候选坐标 = @($候选迁移 | ForEach-Object { "$($_.规格文件)|$($_.事件)|$($_.起始状态)" })
$旧不可达 = @(
    $旧迁移 |
        Where-Object { $_.迁移类型 -ceq "断言型条款" } |
        ForEach-Object { "$($_.规格文件)|$($_.事件)|$($_.起始状态)" }
)
$候选不可达 = @(
    $候选迁移 |
        Where-Object { $_.迁移类型 -ceq "断言型条款" } |
        ForEach-Object { "$($_.规格文件)|$($_.事件)|$($_.起始状态)" }
)
检查 ($旧坐标.Count -eq 115) "旧矩阵迁移坐标应为 115 个，实际为 $($旧坐标.Count)"
检查 (($旧坐标 | Sort-Object -Unique).Count -eq 115) "旧矩阵迁移坐标存在重复"
检查 ($旧不可达.Count -eq 63) "旧矩阵不可达标记应为 63 个，实际为 $($旧不可达.Count)"
检查 ($候选坐标.Count -eq 115) "候选矩阵迁移坐标应为 115 个，实际为 $($候选坐标.Count)"
检查 (($候选坐标 | Sort-Object -Unique).Count -eq 115) "候选矩阵迁移坐标存在重复"
检查 ($候选不可达.Count -eq 63) "候选矩阵不可达标记应为 63 个，实际为 $($候选不可达.Count)"
检查 (集合相同 $旧坐标 $候选坐标) "候选矩阵与旧矩阵的 115 个迁移坐标集合不一致；停止且不得覆盖"
检查 (集合相同 $旧不可达 $候选不可达) "候选矩阵与旧矩阵的不可达标记集合不一致；停止且不得覆盖"

$已覆盖数 = @($正向记录 | Where-Object { $_.判定 -ceq "已覆盖" }).Count
$未覆盖数 = @($正向记录 | Where-Object { $_.判定 -ceq "未覆盖" }).Count
$不适用数 = @($正向记录 | Where-Object { $_.判定 -ceq "不适用" }).Count
$第五类数 = @(
    $正向记录 |
        Where-Object {
            $_.判定 -ceq "不适用" -and
            (取理由类别 $_) -ceq "实现约束比规格更强，该路径在当前实现下不可达"
        }
).Count
检查 ($已覆盖数 + $未覆盖数 + $不适用数 -eq 376) "三类判定数量之和不是 376"
检查 ($已覆盖数 -eq 265) "已覆盖数应为 265，实际为 $已覆盖数"
检查 ($未覆盖数 -eq 72) "未覆盖数应为 72，实际为 $未覆盖数"
检查 ($不适用数 -eq 39) "不适用数应为 39，实际为 $不适用数"
检查 ($第五类数 -eq 2) "第五类不适用应为 2，实际为 $第五类数"

$候选矩阵文本 = 生成矩阵文本 $正向记录 $测试方法
$候选解析记录 = @(解析正向记录 $候选矩阵文本)
检查 ($候选解析记录.Count -eq 376) "候选矩阵回读条款数不是 376"
$回读候选迁移 = @(
    $候选解析记录 |
        Where-Object { -not [string]::IsNullOrEmpty($_.迁移类型) }
)
$回读候选坐标 = @(
    $回读候选迁移 |
        ForEach-Object { "$($_.规格文件)|$($_.事件)|$($_.起始状态)" }
)
$回读候选不可达 = @(
    $回读候选迁移 |
        Where-Object { $_.迁移类型 -ceq "断言型条款" } |
        ForEach-Object { "$($_.规格文件)|$($_.事件)|$($_.起始状态)" }
)
检查 ($回读候选坐标.Count -eq 115) "候选文本回读迁移坐标应为 115 个，实际为 $($回读候选坐标.Count)"
检查 ($回读候选不可达.Count -eq 63) "候选文本回读不可达标记应为 63 个，实际为 $($回读候选不可达.Count)"
检查 (集合相同 $旧坐标 $回读候选坐标) "候选文本回读坐标集合与旧矩阵不一致；停止且不得覆盖"
检查 (集合相同 $旧不可达 $回读候选不可达) "候选文本回读不可达标记集合与旧矩阵不一致；停止且不得覆盖"

$方法命中 = @{}
foreach ($方法名 in $测试方法.Keys) {
    $方法命中[$方法名] = 0
}
foreach ($记录 in $正向记录) {
    foreach ($方法名 in $记录.方法) {
        $方法命中[$方法名]++
    }
}
$未命中数 = @($方法命中.Keys | Where-Object { $方法命中[$_] -eq 0 }).Count
检查 ($未命中数 -eq 8) "未命中测试应为 8，实际为 $未命中数"

Push-Location $项目根
try {
    $允许改动 = @(
        ".github/workflows/ci.yml",
        "Reports/TRACEABILITY-S3-S5.md",
        "Reports/IC-20260812-021-SELF-VERIFICATION.md",
        "Scripts/verify-IC-20260812-021.ps1"
    )
    $改动路径 = @(
        @(& git diff --name-only $旧矩阵提交 --) +
        @(& git ls-files --others --exclude-standard) |
            Where-Object { $_ } |
            Sort-Object -Unique
    )
    foreach ($路径 in $改动路径) {
        检查 ($允许改动 -ccontains $路径) "出现范围外改动：$路径"
    }
    $产品测试改动 = @(
        @(& git diff --name-only $旧矩阵提交 -- PhotoCleanupMVE PhotoCleanupMVETests) +
        @(& git ls-files --others --exclude-standard -- PhotoCleanupMVE PhotoCleanupMVETests) |
            Where-Object { $_ }
    )
    检查 ($产品测试改动.Count -eq 0) "产品代码或测试代码相对重跑基线发生变化"
}
finally {
    Pop-Location
}

$工作流路径 = Join-Path $项目根 ".github/workflows/ci.yml"
$工作流文本 = Get-Content -LiteralPath $工作流路径 -Raw -Encoding UTF8
检查 ($工作流文本.Contains("run: ./Scripts/verify-IC-20260812-021.ps1")) "CI 未运行本卡专项自验"

if (-not $写入矩阵) {
    检查 (Test-Path -LiteralPath $自验报告路径 -PathType Leaf) "缺少本卡自验报告"
    if (Test-Path -LiteralPath $自验报告路径 -PathType Leaf) {
        $报告文本 = Get-Content -LiteralPath $自验报告路径 -Raw -Encoding UTF8
        检查 ($报告文本.Contains("IC-20260812-021")) "自验报告缺少任务编号"
        检查 ($报告文本.Contains("| 条款总数 | 376 |")) "自验报告条款总数不匹配"
        检查 ($报告文本.Contains("| 已覆盖 | 265 |")) "自验报告已覆盖数不匹配"
        检查 ($报告文本.Contains("| 未覆盖 | 72 |")) "自验报告未覆盖数不匹配"
        检查 ($报告文本.Contains("| 不适用 | 39 |")) "自验报告不适用数不匹配"
        检查 ($报告文本.Contains("| 第五类 | 2 |")) "自验报告第五类数量不匹配"
    }
}

if ($失败清单.Count -gt 0) {
    Write-Host "IC-20260812-021 自验失败：共执行 $检查总数 项检查，失败 $($失败清单.Count) 项。" -ForegroundColor Red
    foreach ($失败项 in $失败清单) {
        Write-Host "  - $失败项" -ForegroundColor Red
    }
    exit 1
}

if ($写入矩阵) {
    $当前矩阵文本 = if (Test-Path -LiteralPath $矩阵路径 -PathType Leaf) {
        Get-Content -LiteralPath $矩阵路径 -Raw -Encoding UTF8
    }
    else {
        ""
    }
    $当前可写 = (规范化文本 $当前矩阵文本) -ceq (规范化文本 $旧矩阵文本) -or
        (规范化文本 $当前矩阵文本) -ceq (规范化文本 $候选矩阵文本)
    if (-not $当前可写) {
        Write-Host "IC-20260812-021 写入已停止：当前矩阵既不是旧矩阵，也不是同一候选矩阵；未覆盖任何文件。" -ForegroundColor Red
        exit 1
    }
    [System.IO.File]::WriteAllText(
        $矩阵路径,
        (规范化文本 $候选矩阵文本),
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "一致性闸门通过后已写入候选矩阵。" -ForegroundColor Green
}
else {
    $当前矩阵文本 = Get-Content -LiteralPath $矩阵路径 -Raw -Encoding UTF8
    检查 (
        (规范化文本 $当前矩阵文本) -ceq (规范化文本 $候选矩阵文本)
    ) "当前矩阵与脚本重算候选不一致"
    if ($失败清单.Count -gt 0) {
        Write-Host "IC-20260812-021 自验失败：矩阵最终比对失败。" -ForegroundColor Red
        foreach ($失败项 in $失败清单) {
            Write-Host "  - $失败项" -ForegroundColor Red
        }
        exit 1
    }
}

Write-Host "IC-20260812-021 自验通过：共执行 $检查总数 项检查。" -ForegroundColor Green
Write-Host "统计：条款 376；已覆盖 265；未覆盖 72；不适用 39；第五类 2；XCTest 方法 179；未命中测试 8。"
Write-Host "一致性：迁移坐标 115/115，集合完全一致；不可达标记 63/63，集合完全一致。"
