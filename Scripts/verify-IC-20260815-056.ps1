param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$上游提交 = "d562f1a0248b110ed5da031618a36cd3a4331c50"
$主干提交 = "bccc2d2deadf37da470b9270f25ecb0312e6d4de"
$目标分支 = "feature/ic-056-doubletap-scale"
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
    检查 ($LASTEXITCODE -eq 0) "当前提交不包含 IC-055 交付基线"
    检查 ((git branch --show-current) -eq $目标分支) "当前分支不是指定独立分支"
    检查 ((git rev-parse main) -eq $主干提交) "本地主干出现新提交"
    检查 ((git rev-parse origin/main) -eq $主干提交) "远端跟踪主干出现新提交"

    $测试文件 = Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVETests") -Filter "*.swift" -File
    $全部测试 = @(Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+test')
    检查 ($全部测试.Count -ge 312) "XCTest 静态总数少于 312，实际为 $($全部测试.Count)"

    $专项测试 = 读取 "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift"
    $D测试名 = @(
        "testD1ScreenAspectFitInsetRatioShrinksShortEdgeToNinetyTwoPercent",
        "testD2ZeroFitInsetMatchesPureAspectFit",
        "testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged",
        "testD4ScreenAspectDoubleTapUsesMinimumScale",
        "testD5DoubleTapUsesLargerAspectFillScale",
        "testD6LeftEdgeDoubleTapAlignsLeftContentBoundary",
        "testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary",
        "testD8DoubleTapExitResetsScaleAndOffset"
    )
    $回归测试名 = @(
        "testV1InterfaceVisibilityKeepsViewportSizeEqual",
        "testV2BottomStripStatesKeepViewportSizeAndHeightEqual",
        "testV3SheetPresentationKeepsViewportSizeEqual",
        "testV4AllPresentationStatesShareFitAndDoubleTapMultiplier",
        "testV5ParametersSurviveProcessModelRestart",
        "testV6AllFourImageRequestStrategiesTakeEffectImmediately",
        "testV7MissingAspectCategoryReturnsExplicitEmptyResult",
        "testV8FitInsetRatioGeometryAndScopeAreCorrect",
        "testL1TopOverlayFramesRespectSafeAreaTop",
        "testL2BottomOverlayFramesRespectHomeIndicator",
        "testL3TopOverlayFramesDoNotIntersect",
        "testL4ClickableOverlayControlsMeetMinimumTouchTarget",
        "testL5CalibrationPanelsDoNotChangeViewportSize",
        "testL6CalibrationPanelsStartHiddenWithoutVisibleEntry",
        "testL7FactoryDefaultsMatchSystemParityDecision",
        "testP1NxSingleFingerDragProducesNonzeroPan",
        "testP2NxPanStopsAtContentBoundaryWithoutExtraMargin",
        "testP3OneXSingleFingerDragDoesNotPanPhoto",
        "testR1PinchRequestsExactlyOnceAfterPinchEnded",
        "testR2PinchDoesNotReplaceWithDegradedPreview",
        "testT1AdjacentPageTracksFingerWithSameSignAndMonotonicOffset",
        "testT2BelowSnapThresholdReturnsToCurrentPage",
        "testT3PagingKeepsPhotoSizeAndResetsScaleAfterSwitch"
    )
    foreach ($测试名 in $D测试名 + $回归测试名) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少专项或回归 XCTest：$测试名"
    }
    $D方法数 = ([regex]::Matches($专项测试, '(?m)^\s*func\s+testD[1-8]')).Count
    检查 ($D方法数 -eq 8) "D1 至 D8 应恰有 8 个测试，实际为 $D方法数"

    $标定文本 = 读取 "PhotoCleanupMVE/Features/S2/S2Calibration.swift"
    $视图文本 = 读取 "PhotoCleanupMVE/Features/S2/S2View.swift"
    $状态机文本 = 读取 "PhotoCleanupMVE/Core/S2StateMachine.swift"
    $实现与导出 = $标定文本 + $状态机文本

    检查 (-not $实现与导出.Contains("aspectFillDegenerateTolerancePercent")) "仍保留退化容差参数"
    检查 (-not $实现与导出.Contains("aspectFillDegenerateTargetScale")) "仍保留退化目标参数"
    检查 ([regex]::IsMatch($标定文本, 'minDoubleTapScale:\s*2\.5,')) "minDoubleTapScale 出厂值不是 2.5"
    检查 ($标定文本.Contains('("minDoubleTapScale", formatted(minDoubleTapScale))')) "参数导出缺少 minDoubleTapScale"
    检查 ($标定文本.Contains('taskID", "IC-20260815-056-doubletap-scale-and-anchor')) "参数导出任务标识不正确"
    检查 ($视图文本.Contains("calibrationBinding(\.minDoubleTapScale)")) "调参面板未接入 minDoubleTapScale"
    检查 ($状态机文本.Contains("let nextScale = max(calculatedMultiplier, parameters.minDoubleTapScale)")) "双击目标未按两者取大值"
    检查 (-not $状态机文本.Contains("differencePercent")) "仍保留退化容差判定分支"
    检查 ($状态机文本.Contains("S2Geometry.aspectFillMultiplier(")) "双击未按视口和照片比例计算填满倍数"

    $锚点枚举 = [regex]::Match(
        $状态机文本,
        '(?s)enum S2DoubleTapAnchorStrategy[^\{]*\{(?<body>.*?)\}'
    ).Groups['body'].Value
    $锚点选项 = [regex]::Matches($锚点枚举, '(?m)^\s*case\s+\w+')
    检查 ($锚点选项.Count -eq 1 -and $锚点枚举.Contains("case touchPoint")) "双击锚点未收敛为唯一触点选项"
    检查 (-not $状态机文本.Contains("previousDoubleTapLocation")) "仍保留上一触点锚定状态"
    检查 ($状态机文本.Contains("S2Geometry.clampedOffset(")) "双击锚点未进入内容边界钳制"
    检查 (-not $状态机文本.Contains("extraMargin")) "边界钳制出现额外余量"

    检查 ($标定文本.Contains("? max(0, 1 - CGFloat(configuration.fitInsetRatio))")) "fitInsetRatio 未按整体显示比例生效"
    检查 ($标定文本.Contains("normalizedAssetRatio")) "屏幕比例判定未归一照片方向"
    检查 ($标定文本.Contains("normalizedViewportRatio")) "屏幕比例判定未归一视口方向"
    检查 ($视图文本.Contains("width: pageMetrics.oneXDisplaySize.width")) "1x 显示尺寸未接到渲染层"
    检查 ($视图文本.Contains("height: pageMetrics.oneXDisplaySize.height")) "1x 显示高度未接到渲染层"

    $基线视图 = git show "${上游提交}:PhotoCleanupMVE/Features/S2/S2View.swift" | Out-String
    $当前材质数 = ([regex]::Matches($视图文本, '\.background\(\.regularMaterial\)')).Count
    $基线材质数 = ([regex]::Matches($基线视图, '\.background\(\.regularMaterial\)')).Count
    检查 ($当前材质数 -eq $基线材质数) "系统材质数量发生变化"
    $视图差异 = git diff --unified=0 $上游提交 -- "PhotoCleanupMVE/Features/S2/S2View.swift"
    $新增禁改样式 = @($视图差异 | Where-Object {
        $_ -match '^\+(?!\+\+).*(foregroundStyle|foregroundColor|font|cornerRadius|clipShape|shadow)\('
    })
    检查 ($新增禁改样式.Count -eq 0) "新增了范围外视觉样式"

    $调试定义 = @(Select-String -LiteralPath (Join-Path $项目根 "PhotoCleanupMVE/App/CleanupCoordinator.swift") -Pattern 'static\s+let\s+debugAssetLimit\s*=\s*300')
    检查 ($调试定义.Count -eq 1) "debugAssetLimit 被改动"

    $允许文件 = @(
        "PhotoCleanupMVE/Core/S2StateMachine.swift",
        "PhotoCleanupMVE/Features/S2/S2Calibration.swift",
        "PhotoCleanupMVE/Features/S2/S2View.swift",
        "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift",
        "PhotoCleanupMVETests/S2StateMachineTests.swift",
        "Scripts/verify-IC-20260815-056.ps1",
        "selfcheck_IC-056_report.md"
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
    检查 (Test-Path -LiteralPath (Join-Path $项目根 "selfcheck_IC-056_report.md") -PathType Leaf) "缺少 IC-056 自验报告"
}
finally {
    Pop-Location
}

if ($失败.Count -gt 0) {
    foreach ($项目 in $失败) {
        Write-Host "错误：$项目" -ForegroundColor Red
    }
    Write-Host "IC-056 自验失败：$($失败.Count) 项失败，共执行 $检查数 项检查。" -ForegroundColor Red
    exit 1
}

Write-Host "IC-056 本地自验通过：共执行 $检查数 项检查，静态 XCTest 总数 $($全部测试.Count)，D1 至 D8 与全部指定回归测试均存在。" -ForegroundColor Green
exit 0
