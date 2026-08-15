param(
    [switch]$执行XCTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$上游提交 = "b5d38f01cad45d903d419805ffc27e842f4f25f7"
$主干提交 = "bccc2d2deadf37da470b9270f25ecb0312e6d4de"
$目标分支 = "feature/ic-057-doubletap-response"
$检查数 = 0
$失败 = [System.Collections.Generic.List[string]]::new()

function 检查 {
    param(
        [bool]$条件,
        [string]$说明
    )
    $script:检查数 += 1
    if (-not $条件) {
        $script:失败.Add($说明)
    }
}

function 读取 {
    param([string]$相对路径)
    Get-Content -LiteralPath (Join-Path $项目根 $相对路径) -Raw -Encoding UTF8
}

Push-Location $项目根
try {
    git merge-base --is-ancestor $上游提交 HEAD
    检查 ($LASTEXITCODE -eq 0) "当前提交不包含 IC-056 交付基线"
    检查 ((git branch --show-current) -eq $目标分支) "当前分支不是 IC-057 独立分支"
    检查 ((git rev-parse main) -eq $主干提交) "本地主干出现新提交"
    检查 ((git rev-parse origin/main) -eq $主干提交) "远端跟踪主干出现新提交"

    $测试文件 = Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVETests") -Filter "*.swift" -File
    $全部测试 = @(Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+test')
    检查 ($全部测试.Count -ge 318) "XCTest 静态总数少于 318，实际为 $($全部测试.Count)"

    $专项测试 = 读取 "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift"
    $专项测试名 = @(
        "testD1ScreenAspectFitInsetRatioShrinksShortEdgeToNinetyTwoPercent",
        "testD2ZeroFitInsetMatchesPureAspectFit",
        "testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged",
        "testD4ScreenAspectDoubleTapUsesMinimumScale",
        "testD5DoubleTapUsesLargerAspectFillScale",
        "testD6LeftEdgeDoubleTapAlignsLeftContentBoundary",
        "testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary",
        "testD8DoubleTapExitResetsScaleAndOffset",
        "testE1FirstTapProducesImmediateSingleTapAction",
        "testE2SecondTapWithinDecisionWindowRevertsAppliedSingleTap",
        "testE3TapAfterDecisionWindowStartsNewImmediateSingleTap",
        "testE4RevertedSingleTapThenDoubleTapMatchesDirectDoubleTap",
        "testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale",
        "testE6ReadingsAndParameterPanelsAreMutuallyExclusive",
        "testA1AnimationPolicyDisablesCalibratedAnimations"
    )
    foreach ($测试名 in $专项测试名) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少专项 XCTest：$测试名"
    }
    $E方法数 = ([regex]::Matches($专项测试, '(?m)^\s*func\s+testE[1-6]')).Count
    检查 ($E方法数 -eq 6) "E1 至 E6 应恰有 6 个测试，实际为 $E方法数"

    $标定文本 = 读取 "PhotoCleanupMVE/Features/S2/S2Calibration.swift"
    $视图文本 = 读取 "PhotoCleanupMVE/Features/S2/S2View.swift"
    $状态机文本 = 读取 "PhotoCleanupMVE/Core/S2StateMachine.swift"
    $目录文本 = 读取 "PhotoCleanupMVE/Localizable.xcstrings"
    $实现文本 = $标定文本 + $视图文本 + $状态机文本

    检查 (-not $实现文本.Contains("aspectFillDegenerateTolerancePercent")) "仍保留退化容差参数"
    检查 (-not $实现文本.Contains("aspectFillDegenerateTargetScale")) "仍保留退化目标参数"
    检查 ([regex]::IsMatch($标定文本, 'minDoubleTapScale:\s*2\.5,')) "minDoubleTapScale 出厂值不是 2.5"
    检查 ($视图文本.Contains("calibrationBinding(\.minDoubleTapScale)")) "调参面板未接入 minDoubleTapScale"
    检查 ($状态机文本.Contains("let nextScale = max(calculatedMultiplier, parameters.minDoubleTapScale)")) "双击目标未按填满倍数与最小倍数取大值"
    检查 ($标定文本.Contains("doubleTapTargetScale: max(")) "实时读数目标倍数未使用同一取大公式"

    $锚点枚举 = [regex]::Match(
        $状态机文本,
        '(?s)enum S2DoubleTapAnchorStrategy[^\{]*\{(?<body>.*?)\}'
    ).Groups['body'].Value
    $锚点选项 = [regex]::Matches($锚点枚举, '(?m)^\s*case\s+\w+')
    检查 ($锚点选项.Count -eq 1 -and $锚点枚举.Contains("case touchPoint")) "双击锚点未收敛为唯一触点选项"
    检查 ($状态机文本.Contains("S2Geometry.clampedOffset(")) "双击锚点未进入内容边界钳制"
    检查 (-not $状态机文本.Contains("extraMargin")) "边界钳制出现额外余量"

    检查 ($标定文本.Contains("normalizedAssetRatio")) "屏幕比例判定未归一照片方向"
    检查 ($标定文本.Contains("normalizedViewportRatio")) "屏幕比例判定未归一视口方向"
    检查 ($标定文本.Contains("? max(0, 1 - CGFloat(configuration.fitInsetRatio))")) "fitInsetRatio 未进入 1x 显示尺寸计算"
    检查 ($视图文本.Contains("width: pageMetrics.oneXDisplaySize.width")) "1x 显示宽度未接到渲染层"
    检查 ($视图文本.Contains("height: pageMetrics.oneXDisplaySize.height")) "1x 显示高度未接到渲染层"

    检查 (-not $实现文本.Contains("singleTapDecisionWindowMilliseconds")) "仍保留单击判定等待参数"
    检查 ([regex]::IsMatch($标定文本, 'doubleTapDecisionWindowMilliseconds:\s*320,')) "双击判定窗口出厂值不是 320 毫秒"
    检查 ($标定文本.Contains('("doubleTapDecisionWindowMilliseconds", formatted(doubleTapDecisionWindowMilliseconds))')) "参数导出缺少双击判定窗口"
    检查 (-not $视图文本.Contains("pendingSingleTap")) "单击路径仍保留待执行任务"
    检查 (-not $视图文本.Contains("DispatchWorkItem")) "单击路径仍创建延迟工作项"
    检查 (-not $视图文本.Contains("DispatchQueue.main.asyncAfter")) "单击路径仍等待判定窗口"
    检查 ($视图文本.Contains("case .singleTap:")) "第一击未同步进入单击处理"
    检查 ($视图文本.Contains("applied = machine.handleSingleTap()")) "第一击抬起未立即切换界面"
    检查 ($视图文本.Contains("revertingImmediateSingleTap: revertImmediateSingleTap")) "第二击未请求撤销立即单击"
    检查 ($状态机文本.Contains("visibilityBeforeTapSequence")) "撤销与双击未收敛到同一次状态机调用"
    检查 ($视图文本.Contains("transaction.disablesAnimations = true")) "关闭动画时未禁用视图事务动画"
    检查 ($视图文本.Contains("performWithoutAnimation(action)")) "关闭动画时未走无动画执行路径"

    检查 ($标定文本.Contains("let assetAspectRatio: CGFloat")) "读数模型缺少照片宽高比"
    检查 ($标定文本.Contains("let viewportAspectRatio: CGFloat")) "读数模型缺少视口宽高比"
    检查 ($标定文本.Contains("let doubleTapTargetScale: CGFloat")) "读数模型缺少实际双击目标倍数"
    检查 ($视图文本.Contains('"s2.calibration.reading.asset_ratio"')) "实时读数面板未显示照片宽高比"
    检查 ($视图文本.Contains('"s2.calibration.reading.viewport_ratio"')) "实时读数面板未显示视口宽高比"
    检查 ($视图文本.Contains('"s2.calibration.reading.double_tap_target"')) "实时读数面板未显示双击目标倍数"
    检查 ($目录文本.Contains('"s2.calibration.reading.double_tap_target"')) "String Catalog 缺少双击目标倍数文案"
    检查 ($标定文本.Contains("readingsVisible = false")) "打开参数面板时未释放读数面板空间"
    检查 ($标定文本.Contains("parameterPanelVisible = false")) "打开读数面板时未释放参数面板空间"
    检查 ($标定文本.Contains('taskID", "IC-20260815-057-doubletap-scale-anchor-and-response')) "参数导出任务标识不正确"

    $允许文件 = @(
        "PhotoCleanupMVE/Core/S2StateMachine.swift",
        "PhotoCleanupMVE/Features/S2/S2Calibration.swift",
        "PhotoCleanupMVE/Features/S2/S2View.swift",
        "PhotoCleanupMVE/Localizable.xcstrings",
        "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift",
        "Scripts/verify-IC-20260815-057.ps1",
        "selfcheck_IC-057_report.md"
    )
    $变更文件 = @(
        git diff --name-only $上游提交
        git ls-files --others --exclude-standard
    ) | Sort-Object -Unique
    $范围外文件 = @($变更文件 | Where-Object { $_ -notin $允许文件 })
    检查 ($范围外文件.Count -eq 0) "存在范围外变更文件：$($范围外文件 -join ', ')"
    $禁止文件 = @($变更文件 | Where-Object {
        [System.IO.Path]::GetFileName($_) -like "SPEC-*.md" -or
            [System.IO.Path]::GetFileName($_) -eq "Decision_log.md"
    })
    检查 ($禁止文件.Count -eq 0) "变更清单含禁止修改的规格或决策日志"

    git diff --check $上游提交
    检查 ($LASTEXITCODE -eq 0) "git diff --check 失败"
    & (Join-Path $项目根 "Scripts/selfcheck.ps1")
    检查 ($LASTEXITCODE -eq 0) "仓库结构自验失败"
    检查 (Test-Path -LiteralPath (Join-Path $项目根 "selfcheck_IC-057_report.md") -PathType Leaf) "缺少 IC-057 自验报告"

    if ($执行XCTest) {
        $测试命令 = Get-Command bash -ErrorAction SilentlyContinue
        检查 ($null -ne $测试命令) "当前环境缺少 bash，无法调用 XCTest 脚本"
        if ($null -ne $测试命令) {
            & bash (Join-Path $项目根 "Scripts/test-xcode.sh")
            检查 ($LASTEXITCODE -eq 0) "XCTest 执行失败"
        }
    }
}
finally {
    Pop-Location
}

if ($失败.Count -gt 0) {
    foreach ($项目 in $失败) {
        Write-Host "错误：$项目" -ForegroundColor Red
    }
    Write-Host "IC-057 自验失败：$($失败.Count) 项失败，共执行 $检查数 项检查。" -ForegroundColor Red
    exit 1
}

$XCTest说明 = if ($执行XCTest) { "，并已执行 XCTest" } else { "；未请求执行 XCTest" }
Write-Host "IC-057 本地自验通过：共执行 $检查数 项检查，静态 XCTest 总数 $($全部测试.Count)$XCTest说明。" -ForegroundColor Green
exit 0
