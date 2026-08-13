[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$脚本目录 = Split-Path -Parent $MyInvocation.MyCommand.Path
$项目根 = Split-Path -Parent $脚本目录
$分类报告路径 = Join-Path $项目根 "Reports/GUARD-ASSERTION-STRENGTH.md"
$自验报告路径 = Join-Path $项目根 "Reports/IC-20260812-023-SELF-VERIFICATION.md"
$矩阵路径 = Join-Path $项目根 "Reports/TRACEABILITY-S3-S5.md"
$守卫路径 = Join-Path $项目根 "PhotoCleanupMVETests/TransitionTableGuardTests.swift"
$基线提交 = "45716ff71376a12667f2e105935fd5aeaee81c64"
$允许改动 = @(
    "Reports/GUARD-ASSERTION-STRENGTH.md",
    "Reports/IC-20260812-023-SELF-VERIFICATION.md",
    "Scripts/verify-IC-20260812-023.ps1"
)

$检查总数 = 0
$失败清单 = [System.Collections.Generic.List[string]]::new()

function 检查 {
    param(
        [bool]$条件,
        [string]$说明
    )

    $script:检查总数++
    if (-not $条件) {
        $script:失败清单.Add($说明)
    }
}

function 集合相同 {
    param(
        [object[]]$左侧,
        [object[]]$右侧
    )

    $仅左侧 = @($左侧 | Where-Object { $右侧 -cnotcontains $_ })
    $仅右侧 = @($右侧 | Where-Object { $左侧 -cnotcontains $_ })
    return $仅左侧.Count -eq 0 -and $仅右侧.Count -eq 0
}

function 调用Git {
    param([string[]]$参数)

    Push-Location $项目根
    try {
        $输出 = @(& git @参数 2>&1)
        $退出码 = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($退出码 -ne 0) {
        throw "Git 命令执行失败：git $($参数 -join ' ')；输出：$($输出 -join ' ')"
    }
    return @($输出 | ForEach-Object { [string]$_ })
}

function 获取期望判定 {
    param([object]$记录)

    $强度 = "未映射"
    $行号 = "未映射"

    if ($记录.规格 -ceq "SPEC-S3-S4-20260812.v6.md") {
        if ($记录.状态 -ceq "S3-2 外部源") {
            $强度 = "弱"
            $行号 = "149-160"
        }
        elseif ($记录.状态.StartsWith("S3-") -or $记录.状态 -ceq "页面外") {
            if ($记录.状态 -ceq "页面外") {
                $强度 = "弱"
                $行号 = "115-121"
            }
            elseif ($记录.事件 -ceq "进入页面") {
                $强度 = "弱"
                $行号 = "124-127"
            }
            elseif (@("扫描完成", "扫描中移除项") -ccontains $记录.事件) {
                $强度 = "弱"
                $行号 = "124,128-130"
            }
            elseif ($记录.事件 -ceq "移除单项") {
                $强度 = "强"
                $行号 = "124,131-132"
            }
            elseif ($记录.事件 -ceq "全部取消") {
                $强度 = "强"
                $行号 = "124,133-134"
            }
            elseif ($记录.事件 -ceq "集合变为空") {
                $强度 = "强"
                $行号 = "124,135-136"
            }
            elseif ($记录.事件 -ceq "点击提交") {
                $强度 = "强"
                $行号 = "124,137-142"
            }
        }
        elseif ($记录.事件 -ceq "提交发起") {
            $强度 = "强"
            $行号 = "163-171"
        }
        elseif ($记录.事件 -ceq "收到成功回调") {
            $强度 = "强"
            $行号 = "163,172-180"
        }
        elseif ($记录.事件 -ceq "收到失败回调") {
            $强度 = "强"
            $行号 = "163,181-186"
        }
        elseif ($记录.事件 -ceq "超时触发") {
            $强度 = "强"
            $行号 = "163,187-192"
        }
    }
    elseif ($记录.规格 -ceq "SPEC-S5-20260812.v5.md") {
        if ($记录.状态 -ceq "外部源") {
            $强度 = "弱"
            $行号 = "199-205"
        }
        elseif ($记录.事件.StartsWith("从 S4-")) {
            $强度 = "弱"
            $行号 = "207-210"
        }
        elseif ($记录.事件 -ceq '用户点击“我已清空最近删除”') {
            $强度 = "强"
            $行号 = "213-220,232-237"
        }
        elseif ($记录.事件 -ceq '用户点击“返回确认页”') {
            $强度 = "强"
            $行号 = "213,221-225,232-237"
        }
        elseif ($记录.事件 -ceq "用户离开页面") {
            $强度 = "强"
            $行号 = "213,226-227,232-237"
        }
    }

    return [pscustomobject]@{
        强度 = $强度
        行号 = $行号
    }
}

检查 (Test-Path -LiteralPath $分类报告路径 -PathType Leaf) "缺少分类报告"
检查 (Test-Path -LiteralPath $自验报告路径 -PathType Leaf) "缺少自验报告"
检查 (Test-Path -LiteralPath $矩阵路径 -PathType Leaf) "缺少追溯矩阵"
检查 (Test-Path -LiteralPath $守卫路径 -PathType Leaf) "缺少迁移表守卫测试"

$迁移记录 = [System.Collections.Generic.List[object]]::new()
foreach ($行 in Get-Content -LiteralPath $矩阵路径 -Encoding UTF8) {
    $字段 = $行 -split "`t", 7
    if ($字段.Count -ne 7) {
        continue
    }
    if ($字段[6] -cmatch '^(可达单元格|断言型条款)（事件“(.+)” × 起始状态“([^”]+)”）') {
        $类型 = $Matches[1]
        $事件 = $Matches[2]
        $状态 = $Matches[3]
        $迁移记录.Add([pscustomobject]@{
            条款 = $字段[0]
            规格 = $字段[1]
            事件 = $事件
            状态 = $状态
            类型 = $类型
            坐标 = "$($字段[1])|$事件|$状态"
        })
    }
}

$不可达记录 = @($迁移记录 | Where-Object { $_.类型 -ceq "断言型条款" })
检查 ($迁移记录.Count -eq 115) "追溯矩阵迁移单元格应为 115 个，实际为 $($迁移记录.Count)"
检查 ($不可达记录.Count -eq 63) "追溯矩阵不可达单元格应为 63 个，实际为 $($不可达记录.Count)"
检查 ((@($不可达记录.条款 | Sort-Object -Unique)).Count -eq 63) "追溯矩阵不可达条款号存在重复"
检查 ((@($不可达记录.坐标 | Sort-Object -Unique)).Count -eq 63) "追溯矩阵不可达坐标存在重复"

$分类报告文本 = Get-Content -LiteralPath $分类报告路径 -Raw -Encoding UTF8
$分类记录 = [System.Collections.Generic.List[object]]::new()
foreach ($行 in Get-Content -LiteralPath $分类报告路径 -Encoding UTF8) {
    if ($行 -cmatch '^\|\s*(C(?:34|5)-\d{3})<br><code>([^<]+)</code>\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*(强|弱)\s*\|\s*(.+)\s*\|$') {
        $条款 = $Matches[1]
        $坐标 = $Matches[2].Replace("&#124;", "|")
        $事件 = $Matches[3].Trim()
        $状态 = $Matches[4].Trim()
        $强度 = $Matches[5]
        $依据 = $Matches[6].Trim()
        $坐标字段 = $坐标 -split '\|', 3
        $规格 = if ($坐标字段.Count -eq 3) { $坐标字段[0] } else { "" }
        $分类记录.Add([pscustomobject]@{
            条款 = $条款
            规格 = $规格
            事件 = $事件
            状态 = $状态
            坐标 = $坐标
            强度 = $强度
            依据 = $依据
        })
    }
}

检查 ($分类记录.Count -eq 63) "分类表应为 63 行，实际为 $($分类记录.Count)"
检查 ((@($分类记录.条款 | Sort-Object -Unique)).Count -eq 63) "分类表条款号存在重复"
检查 ((@($分类记录.坐标 | Sort-Object -Unique)).Count -eq 63) "分类表坐标存在重复"
检查 ((@($分类记录 | Where-Object { $_.强度 -ceq "强" })).Count -eq 26) "强断言应为 26 个"
检查 ((@($分类记录 | Where-Object { $_.强度 -ceq "弱" })).Count -eq 37) "弱断言应为 37 个"
检查 (集合相同 @($不可达记录.条款) @($分类记录.条款)) "分类表与矩阵的不可达条款集合不一致"
检查 (集合相同 @($不可达记录.坐标) @($分类记录.坐标)) "分类表与矩阵的不可达坐标集合不一致"

$矩阵索引 = @{}
foreach ($记录 in $不可达记录) {
    $矩阵索引[$记录.坐标] = $记录
}

foreach ($记录 in $分类记录) {
    检查 ($记录.坐标 -ceq "$($记录.规格)|$($记录.事件)|$($记录.状态)") "分类表坐标字段不自洽：$($记录.条款)"
    检查 ($矩阵索引.ContainsKey($记录.坐标)) "分类表坐标未出现在不可达矩阵：$($记录.条款)"
    if (-not $矩阵索引.ContainsKey($记录.坐标)) {
        continue
    }

    $矩阵项 = $矩阵索引[$记录.坐标]
    检查 ($记录.条款 -ceq $矩阵项.条款) "分类表条款号与坐标不匹配：$($记录.条款)"
    $期望 = 获取期望判定 $记录
    检查 ($期望.强度 -cne "未映射") "分类规则未覆盖：$($记录.坐标)"
    检查 ($记录.强度 -ceq $期望.强度) "断言强度不匹配：$($记录.坐标)"
    检查 ($记录.依据.Contains("TransitionTableGuardTests.swift:$($期望.行号)")) "测试代码行号依据不匹配：$($记录.坐标)"
    if ($记录.强度 -ceq "强") {
        检查 ($记录.依据.Contains("调用") -and $记录.依据.Contains("断言")) "强断言依据未同时说明调用与断言：$($记录.坐标)"
    }
    else {
        检查 (
            $记录.依据.Contains("未提交") -or
            $记录.依据.Contains("未构造状态机或提交事件")
        ) "弱断言依据未说明事件未提交：$($记录.坐标)"
    }
}

检查 (-not ($分类报告文本 -cmatch '建议|改进|补强|改成强断言')) "分类报告包含范围外的改进建议"

$守卫行 = @(Get-Content -LiteralPath $守卫路径 -Encoding UTF8)
$关键行 = @(
    @(115, 'if cell.sourceState == "页面外"'),
    @(116, 'XCTAssertFalse('),
    @(121, 'return'),
    @(124, 'let machine = try makeS3Machine'),
    @(126, 'case "进入页面"'),
    @(127, 'XCTAssertEqual(machine.state.rawValue'),
    @(128, 'case "扫描完成", "扫描中移除项"'),
    @(129, 'XCTAssertNotEqual(machine.state, .scanning'),
    @(130, 'XCTAssertTrue(machine.pendingScanAssetIDs.isEmpty'),
    @(131, 'case "移除单项"'),
    @(132, 'machine.removeAsset'),
    @(133, 'case "全部取消"'),
    @(134, 'machine.cancelAll()'),
    @(135, 'case "集合变为空"'),
    @(136, 'machine.collectionBecameEmpty()'),
    @(137, 'case "点击提交"'),
    @(139, 'machine.freezeSubmissionSnapshot()'),
    @(142, 'XCTAssertEqual(rejectedState, machine.state'),
    @(149, 'if cell.sourceState == "S3-2 外部源"'),
    @(150, 'XCTAssertFalse('),
    @(160, 'return'),
    @(163, 'var machine = try makeS4Machine'),
    @(166, 'case "提交发起"'),
    @(167, 'transition = try machine.handle('),
    @(168, '.duplicateSubmissionAttempt'),
    @(171, 'transition.rejection, .duplicateSubmission'),
    @(172, 'case "收到成功回调"'),
    @(173, 'transition = try machine.handle('),
    @(180, 'transition.rejection, .terminalAlreadyClosed'),
    @(181, 'case "收到失败回调"'),
    @(182, 'transition = try machine.handle('),
    @(186, 'transition.rejection, .terminalAlreadyClosed'),
    @(187, 'case "超时触发"'),
    @(188, 'transition = try machine.handle('),
    @(192, 'transition.rejection, .terminalAlreadyClosed'),
    @(199, 'if cell.sourceState == "外部源"'),
    @(200, 'XCTAssertFalse('),
    @(204, 'return'),
    @(207, 'if cell.event.hasPrefix("从 S4-")'),
    @(208, 'let machine = try makeS5Machine'),
    @(209, 'XCTAssertEqual(machine.state.downstreamTargetState.rawValue'),
    @(210, 'return'),
    @(213, 'var machine = try makeS5Machine'),
    @(216, 'case "用户点击“我已清空最近删除”"'),
    @(217, 'transition = try machine.handle('),
    @(221, 'case "用户点击“返回确认页”"'),
    @(222, 'transition = try machine.handle('),
    @(226, 'case "用户离开页面"'),
    @(227, 'transition = try machine.handle('),
    @(232, 'XCTAssertEqual('),
    @(233, 'transition.rejection'),
    @(234, '.actionUnavailableInCurrentState'),
    @(237, 'XCTAssertEqual(transition.effect, .none')
)

foreach ($项 in $关键行) {
    $行号 = [int]$项[0]
    $片段 = [string]$项[1]
    检查 ($守卫行.Count -ge $行号) "测试代码不存在第 $行号 行"
    if ($守卫行.Count -ge $行号) {
        检查 ($守卫行[$行号 - 1].Contains($片段)) "测试代码第 $行号 行与分类依据不符：$片段"
    }
}

$基线路径 = @(调用Git @("ls-tree", "-r", "--name-only", $基线提交, "--", "PhotoCleanupMVE", "PhotoCleanupMVETests"))
$当前路径 = @(调用Git @("ls-tree", "-r", "--name-only", "HEAD", "--", "PhotoCleanupMVE", "PhotoCleanupMVETests"))
检查 ($基线路径.Count -gt 0) "基线提交未包含受保护文件"
检查 (集合相同 $基线路径 $当前路径) "当前 HEAD 与基线的产品/XCTest 路径集合不一致"

foreach ($路径 in $基线路径) {
    $基线Blob = @(调用Git @("rev-parse", "${基线提交}:$路径"))[0]
    $当前Blob = @(调用Git @("rev-parse", "HEAD:$路径"))[0]
    检查 ($当前Blob -ceq $基线Blob) "当前 HEAD 的受保护 Git blob 已变化：$路径"

    $完整路径 = Join-Path $项目根 $路径
    检查 (Test-Path -LiteralPath $完整路径 -PathType Leaf) "工作树缺少受保护文件：$路径"
    if (Test-Path -LiteralPath $完整路径 -PathType Leaf) {
        $工作树Blob = @(调用Git @("hash-object", "--", $路径))[0]
        检查 ($工作树Blob -ceq $基线Blob) "工作树的受保护 Git blob 已变化：$路径"
    }
}

$未跟踪保护文件 = @(调用Git @("ls-files", "--others", "--exclude-standard", "--", "PhotoCleanupMVE", "PhotoCleanupMVETests"))
检查 ($未跟踪保护文件.Count -eq 0) "产品/XCTest 路径出现未跟踪文件"

$改动路径 = @(
    @(调用Git @("diff", "--name-only", $基线提交, "HEAD", "--")) +
    @(调用Git @("diff", "--name-only", "--")) +
    @(调用Git @("diff", "--cached", "--name-only", "--")) +
    @(调用Git @("ls-files", "--others", "--exclude-standard")) |
        Where-Object { $_ } |
        Sort-Object -Unique
)
foreach ($路径 in $改动路径) {
    检查 ($允许改动 -ccontains $路径) "出现范围外改动：$路径"
}
foreach ($路径 in $允许改动) {
    检查 (Test-Path -LiteralPath (Join-Path $项目根 $路径) -PathType Leaf) "缺少交付物：$路径"
}

$自验报告文本 = Get-Content -LiteralPath $自验报告路径 -Raw -Encoding UTF8
检查 ($自验报告文本.Contains("IC-20260812-023")) "自验报告缺少任务编号"
检查 ($自验报告文本.Contains("| 强断言 | 26 |")) "自验报告强断言数量不匹配"
检查 ($自验报告文本.Contains("| 弱断言 | 37 |")) "自验报告弱断言数量不匹配"
检查 ($自验报告文本.Contains("| 受保护 Git blob | 通过 |")) "自验报告缺少受保护 blob 结论"

if ($失败清单.Count -gt 0) {
    Write-Host "IC-20260812-023 自验失败：共执行 $检查总数 项检查，失败 $($失败清单.Count) 项。" -ForegroundColor Red
    foreach ($失败项 in $失败清单) {
        Write-Host "  - $失败项" -ForegroundColor Red
    }
    exit 1
}

Write-Host "IC-20260812-023 自验通过：共执行 $检查总数 项检查。" -ForegroundColor Green
Write-Host "统计：不可达坐标 63；强断言 26；弱断言 37；无遗漏、无重复。"
Write-Host "保护：产品代码与 XCTest 的 Git blob 相对基线提交全部未变；改动仅限三项交付物。"
