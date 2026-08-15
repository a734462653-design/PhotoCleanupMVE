param(
    [switch]$执行XCTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$继承提交 = "5980c0b"
$主干提交 = "bccc2d2deadf37da470b9270f25ecb0312e6d4de"
$目标分支 = "feature/ic-058-native-zoom-paging"
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
    git merge-base --is-ancestor $继承提交 HEAD
    检查 ($LASTEXITCODE -eq 0) "当前提交不包含已审计的 IC-057 继承提交"
    检查 ((git branch --show-current) -eq $目标分支) "当前分支不是 IC-058 独立分支"
    检查 ((git rev-parse main) -eq $主干提交) "本地主干出现新提交"
    检查 ((git rev-parse origin/main) -eq $主干提交) "远端跟踪主干出现新提交"

    $测试文件 = Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVETests") -Filter "*.swift" -File
    $全部测试 = @(Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+test')
    检查 ($全部测试.Count -ge 326) "XCTest 静态总数少于 326，实际为 $($全部测试.Count)"

    $专项测试 = 读取 "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift"
    $专项测试名 = @(
        "testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale",
        "testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale",
        "testN3NativePagingUsesConfiguredPageSpacing",
        "testN4PageSpacingFactoryDefaultIsTwentyPoints",
        "testN5NxSingleTapTogglesInterfaceWithoutChangingNativeViewport",
        "testN6OneXSingleTapTogglesInterfaceVisibility",
        "testN7NativePageChangeResetsZoomToOne",
        "testN8NativePinchRequestsZeroDuringGestureAndOnceAfterEnd",
        "testE1FirstTapProducesImmediateSingleTapAction",
        "testE2SecondTapWithinDecisionWindowRevertsAppliedSingleTap",
        "testE3TapAfterDecisionWindowStartsNewImmediateSingleTap",
        "testE4RevertedSingleTapThenDoubleTapMatchesDirectDoubleTap",
        "testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale",
        "testE6ReadingsAndParameterPanelsAreMutuallyExclusive",
        "testD1ScreenAspectFitInsetRatioShrinksShortEdgeToNinetyTwoPercent",
        "testD2ZeroFitInsetMatchesPureAspectFit",
        "testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged",
        "testD4ScreenAspectDoubleTapUsesMinimumScale",
        "testD5DoubleTapUsesLargerAspectFillScale",
        "testD6LeftEdgeDoubleTapAlignsLeftContentBoundary",
        "testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary",
        "testD8DoubleTapExitResetsScaleAndOffset",
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
    foreach ($测试名 in $专项测试名) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少专项或指定回归 XCTest：$测试名"
    }
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testN[1-8]')).Count -eq 8) "N1 至 N8 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testE[1-6]')).Count -eq 6) "E1 至 E6 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testD[1-8]')).Count -eq 8) "D1 至 D8 数量不正确"

    $标定文本 = 读取 "PhotoCleanupMVE/Features/S2/S2Calibration.swift"
    $视图文本 = 读取 "PhotoCleanupMVE/Features/S2/S2View.swift"
    $原生容器文本 = 读取 "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
    $状态机文本 = 读取 "PhotoCleanupMVE/Core/S2StateMachine.swift"
    $状态机测试文本 = 读取 "PhotoCleanupMVETests/S2StateMachineTests.swift"
    $工程文本 = 读取 "PhotoCleanupMVE.xcodeproj/project.pbxproj"

    检查 ($原生容器文本.Contains("final class S2NativeZoomScrollView: UIScrollView")) "主图缩放容器不是 UIScrollView"
    检查 ($原生容器文本.Contains("minimumZoomScale = 1")) "原生缩放下限未设为 1"
    检查 ($原生容器文本.Contains("maximumZoomScale: CGFloat(configuration.pinchMaxScale)")) "原生缩放上限未接入 pinchMaxScale"
    检查 ($原生容器文本.Contains("zoom(to: targetRect, animated: animated)")) "双击未调用原生 zoom(to:animated:)"
    检查 (-not $视图文本.Contains("MagnifyGesture")) "S2View 仍使用自定义 MagnifyGesture"
    检查 (-not $视图文本.Contains("private func mainDragGesture")) "S2 主图仍使用自定义拖动实现"
    检查 (-not $视图文本.Contains("scaleEffect(scale)")) "S2 主图仍使用手写缩放变换"
    检查 (-not $状态机文本.Contains("enum S2PagingInteraction")) "仍保留手写分页计算器"
    检查 (-not $原生容器文本.Contains("isAtHorizontalBoundary")) "原生嵌套滚动仍包含手写边界计算"
    检查 (-not $原生容器文本.Contains("holdPaging")) "原生嵌套滚动仍手动锁定分页偏移"

    检查 ($原生容器文本.Contains("final class S2NativePagingScrollView: UIScrollView")) "分页容器不是 UIScrollView"
    检查 ($原生容器文本.Contains("isPagingEnabled = true")) "分页容器未启用原生分页"
    检查 ($原生容器文本.Contains("width: pageWidth") -and $原生容器文本.Contains("pageSpacing / 2")) "分页单元与间距未独立布局"
    检查 ([regex]::IsMatch($标定文本, 'pageSpacing:\s*20,')) "pageSpacing 出厂值不是 20"
    检查 ($标定文本.Contains('("pageSpacing", formatted(pageSpacing))')) "参数导出缺少 pageSpacing"
    检查 ($视图文本.Contains("calibrationBinding(\.pageSpacing)")) "参数面板未接入 pageSpacing"
    检查 ($工程文本.Contains("S2NativePhotoPager.swift")) "Xcode 工程未引用原生容器源码"

    检查 ($状态机文本.Contains("func handleNativeDoubleTap(")) "状态机缺少原生双击结果入口"
    检查 ($状态机文本.Contains("func reportNativeViewport(")) "状态机缺少原生视口上报入口"
    检查 ($状态机文本.Contains("func handleNativePageChange(to index: Int)")) "状态机缺少原生落页上报入口"
    检查 ($状态机文本.Contains("func finishNativePinch(")) "状态机缺少原生捏合结束入口"
    检查 ($状态机文本.Contains("private(set) var imageRequestScale")) "捏合请求倍率未与实时缩放隔离"
    检查 ($状态机测试文本.Contains("availableState(.hiddenNx)")) "Nx 单击迁移表未切换到隐藏态"
    检查 ($状态机测试文本.Contains("availableState(.visibleNxIdle)")) "隐藏 Nx 单击迁移表未切换到显示态"

    检查 ($专项测试.Contains("pageSpacing=20.000000")) "测试未覆盖 pageSpacing 导出样例"
    检查 ($专项测试.Contains("minDoubleTapScale=2.500000")) "测试未覆盖 minDoubleTapScale 导出样例"
    检查 ($标定文本.Contains('taskID", "IC-20260815-058-s2-native-zoom-paging')) "参数导出任务标识不正确"

    $基线视图 = git show "${继承提交}:PhotoCleanupMVE/Features/S2/S2View.swift" | Out-String
    $当前材质数 = ([regex]::Matches($视图文本, '\.background\(\.regularMaterial\)')).Count
    $基线材质数 = ([regex]::Matches($基线视图, '\.background\(\.regularMaterial\)')).Count
    检查 ($当前材质数 -eq $基线材质数) "系统材质数量发生变化"
    $调试定义 = @(Select-String -LiteralPath (Join-Path $项目根 "PhotoCleanupMVE/App/CleanupCoordinator.swift") -Pattern 'static\s+let\s+debugAssetLimit\s*=\s*300')
    检查 ($调试定义.Count -eq 1) "debugAssetLimit 被改动"

    $允许文件 = @(
        "PhotoCleanupMVE.xcodeproj/project.pbxproj",
        "PhotoCleanupMVE/Core/S2StateMachine.swift",
        "PhotoCleanupMVE/Features/S2/S2Calibration.swift",
        "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift",
        "PhotoCleanupMVE/Features/S2/S2View.swift",
        "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift",
        "PhotoCleanupMVETests/S2StateMachineTests.swift",
        "Scripts/verify-IC-20260815-058.ps1",
        "selfcheck_IC-058_report.md"
    )
    $变更文件 = @(
        git diff --name-only $继承提交
        git ls-files --others --exclude-standard
    ) | Sort-Object -Unique
    $范围外文件 = @($变更文件 | Where-Object { $_ -notin $允许文件 })
    检查 ($范围外文件.Count -eq 0) "存在范围外变更文件：$($范围外文件 -join ', ')"
    $禁止文件 = @($变更文件 | Where-Object {
        [System.IO.Path]::GetFileName($_) -like "SPEC-*.md" -or
            [System.IO.Path]::GetFileName($_) -eq "Decision_log.md"
    })
    检查 ($禁止文件.Count -eq 0) "变更清单含禁止修改的规格或决策日志"

    git diff --check $继承提交
    检查 ($LASTEXITCODE -eq 0) "git diff --check 失败"
    & (Join-Path $项目根 "Scripts/selfcheck.ps1")
    检查 ($LASTEXITCODE -eq 0) "仓库结构自验失败"
    检查 (Test-Path -LiteralPath (Join-Path $项目根 "selfcheck_IC-058_report.md") -PathType Leaf) "缺少 IC-058 自验报告"

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
    Write-Host "IC-058 自验失败：$($失败.Count) 项失败，共执行 $检查数 项检查。" -ForegroundColor Red
    exit 1
}

$XCTest说明 = if ($执行XCTest) { "，并已执行 XCTest" } else { "；未请求执行 XCTest" }
Write-Host "IC-058 本地自验通过：共执行 $检查数 项检查，静态 XCTest 总数 $($全部测试.Count)$XCTest说明。" -ForegroundColor Green
exit 0
