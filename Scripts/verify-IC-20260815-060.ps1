param(
    [switch]$执行XCTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$继承提交 = "b58cb2be94953ab58cb07ea06ab34cbcc238eb46"
$主干提交 = "bccc2d2deadf37da470b9270f25ecb0312e6d4de"
$目标分支 = "feature/ic-060-tap-and-immersive"
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
    检查 ($LASTEXITCODE -eq 0) "当前提交不包含已审计的 IC-059 继承提交"
    检查 ((git branch --show-current) -eq $目标分支) "当前分支不是 IC-060 独立分支"
    检查 ((git rev-parse main) -eq $主干提交) "本地主干出现新提交"
    检查 ((git rev-parse origin/main) -eq $主干提交) "远端跟踪主干出现新提交"

    $测试文件 = Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVETests") -Filter "*.swift" -File
    $全部测试 = @(Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+test')
    检查 ($全部测试.Count -ge 354) "XCTest 静态总数少于 354，实际为 $($全部测试.Count)"

    $专项测试 = 读取 "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift"
    $十三项 = @(
        "testK1SingleTapRequiresDoubleTapRecognizerToFail",
        "testK2DoubleTapNeverChangesInterfaceVisibilityAndReachesTargetScale",
        "testK3SingleTapAfterDoubleTapFailureTogglesVisibilityExactlyOnce",
        "testK4DoubleTapDecisionWindowFactoryDefaultIsTwoHundredMilliseconds",
        "testS1FramedPhotoVisibleStateUsesSeventyPercentShortEdgeAndRadiusTwentyEight",
        "testS2FramedPhotoHiddenStateFitsViewportWithoutCroppingAndHasZeroRadius",
        "testS3NonFramedPhotoGeometryIsEqualAcrossVisibilityStates",
        "testS4ImmersiveTogglePreservesViewportFillMultiplierAndDoubleTapTarget",
        "testS5DisabledScreenshotImmersiveKeepsPhoneFrameWhenHidden",
        "testS6ScreenshotImmersiveFactoryDefaultIsTrue",
        "testA1NativePagingPhotoSwitchProducesNoHaptic",
        "testA2BottomStripCurrentItemChangesProduceExactlyNHaptics",
        "testA3DisabledPhotoSwitchHapticProducesNoHaptic"
    )
    foreach ($测试名 in $十三项) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少 IC-060 XCTest：$测试名"
    }
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testK[1-4]')).Count -eq 4) "K1 至 K4 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testS[1-6]')).Count -eq 6) "S1 至 S6 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testA[1-3]')).Count -eq 3) "A1 至 A3 数量不正确"

    $回归测试名 = @(
        "testG1OneXSwipeUpMarksCurrentAsset",
        "testG2NxSwipeUpMarksCurrentAsset",
        "testG3ReplacementNativeDoubleTapDoesNotApplyOrRevertSingleTap",
        "testG4ReplacementTwoUIKitResolvedSingleTapsToggleTwiceWithoutZoom",
        "testM1ScreenAspectDoubleTapUsesMinimumScale",
        "testM2NonScreenPhotoDoubleTapUsesAspectFillScale",
        "testF1FactoryInsetShrinksShortEdgeToSeventyPercent",
        "testF2CornerRadiusAppliesOnlyToInsetPhotos",
        "testF3ReplacementNonFramedPhotoKeepsGeometryAcrossVisibility",
        "testF4InsetDoesNotChangeViewportOrAspectFillMultiplier",
        "testB1NxBoundaryContinuationProducesPagingDisplacement",
        "testB2NxBoundaryPagingBelowThresholdKeepsCurrentIndex",
        "testB3NxBoundaryPagingCompletionResetsNewPhotoScale",
        "testH1ReplacementEnabledHapticFiresOnlyForBottomStripChanges",
        "testH2ReplacementDisabledPhotoSwitchHapticDoesNotFire",
        "testN1NativeZoomContainerUsesConfiguredMinimumAndMaximumScale",
        "testN2DoubleTapInvokesNativeZoomWithResolvedTargetScale",
        "testN3NativePagingUsesConfiguredPageSpacing",
        "testN4PageSpacingFactoryDefaultIsTwentyPoints",
        "testN5NxSingleTapTogglesInterfaceWithoutChangingNativeViewport",
        "testN6OneXSingleTapTogglesInterfaceVisibility",
        "testN7NativePageChangeResetsZoomToOne",
        "testN8NativePinchRequestsZeroDuringGestureAndOnceAfterEnd",
        "testE1ReplacementSingleTapRunsAfterDoubleTapFailure",
        "testE2ReplacementDoubleTapSuppressesSingleTapAction",
        "testE3ReplacementTwoResolvedSingleTapsToggleTwice",
        "testE4ReplacementRecognizedDoubleTapMatchesDirectDoubleTap",
        "testE5ReadingsExposeAspectRatiosAndDoubleTapTargetScale",
        "testE6ReadingsAndParameterPanelsAreMutuallyExclusive",
        "testD1ReplacementScreenAspectFitInsetShrinksShortEdgeToSeventyPercent",
        "testD2ZeroFitInsetMatchesPureAspectFit",
        "testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged",
        "testD4ScreenAspectDoubleTapUsesMinimumScale",
        "testD5ReplacementNonScreenDoubleTapUsesAspectFillScale",
        "testD6LeftEdgeDoubleTapAlignsLeftContentBoundary",
        "testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary",
        "testD8DoubleTapExitResetsScaleAndOffset",
        "testV4ReplacementPresentationStatesPreserveViewportAndZoomBaselines"
    )
    foreach ($测试名 in $回归测试名) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少指定回归 XCTest：$测试名"
    }
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testG[1-4]')).Count -eq 4) "G1 至 G4 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testM[1-2]')).Count -eq 2) "M1 至 M2 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testF[1-4]')).Count -eq 4) "F1 至 F4 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testB[1-3]')).Count -eq 3) "B1 至 B3 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testH[1-2]')).Count -eq 2) "H1 至 H2 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testN[1-8]')).Count -eq 8) "N1 至 N8 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testE[1-6]')).Count -eq 6) "E1 至 E6 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testD[1-8]')).Count -eq 8) "D1 至 D8 数量不正确"

    $标定文本 = 读取 "PhotoCleanupMVE/Features/S2/S2Calibration.swift"
    $原生容器文本 = 读取 "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
    $视图文本 = 读取 "PhotoCleanupMVE/Features/S2/S2View.swift"
    $状态机文本 = 读取 "PhotoCleanupMVE/Core/S2StateMachine.swift"

    检查 ([regex]::IsMatch($标定文本, 'doubleTapDecisionWindowMilliseconds:\s*200,')) "双击裁决诊断目标出厂值不是 200"
    检查 ([regex]::IsMatch($标定文本, 'screenshotImmersiveOnHide:\s*true,')) "截图沉浸开关出厂值不是 true"
    检查 ([regex]::IsMatch($标定文本, 'fitInsetRatio:\s*0\.30,')) "fitInsetRatio 出厂值不是 0.30"
    检查 ([regex]::IsMatch($标定文本, 'fitCornerRadius:\s*28,')) "fitCornerRadius 出厂值不是 28"
    检查 ([regex]::IsMatch($标定文本, 'minDoubleTapScale:\s*2\.5,')) "minDoubleTapScale 出厂值不是 2.5"
    检查 ([regex]::IsMatch($标定文本, 'pageSpacing:\s*20,')) "pageSpacing 出厂值不是 20"
    检查 ([regex]::IsMatch($标定文本, 'hapticOnPhotoSwitch:\s*true,')) "hapticOnPhotoSwitch 出厂值不是 true"
    检查 ($标定文本.Contains('("screenshotImmersiveOnHide", String(screenshotImmersiveOnHide))')) "参数导出缺少截图沉浸开关"
    检查 ($标定文本.Contains('("doubleTapDecisionWindowMilliseconds", formatted(doubleTapDecisionWindowMilliseconds))')) "参数导出缺少双击裁决诊断目标"
    检查 ($标定文本.Contains("S2TapDecisionDiagnosticPolicy")) "双击裁决参数没有实际诊断作用"
    检查 ([regex]::IsMatch($视图文本, 'calibrationBinding\(\s*\\\.doubleTapDecisionWindowMilliseconds\s*\)')) "双击裁决诊断目标未接入面板"
    检查 ($视图文本.Contains("calibrationBinding(\.screenshotImmersiveOnHide)")) "截图沉浸开关未接入面板"

    检查 ($原生容器文本.Contains("singleTapRecognizer.require(toFail: doubleTapRecognizer)")) "单击未显式等待双击识别失败"
    检查 (-not $原生容器文本.Contains("shouldRecognizeSimultaneouslyWith")) "仍允许单击与双击同时识别"
    检查 (-not $原生容器文本.Contains("immediateSingleTapWasApplied")) "仍保留首击立即生效状态"
    检查 (-not $状态机文本.Contains("revertingImmediateSingleTap")) "状态机仍保留双击撤销单击逻辑"
    检查 (-not $状态机文本.Contains("visibilityBeforeDoubleTapZoom")) "双击仍可能恢复旧显隐状态"
    检查 (-not $原生容器文本.Contains("S2TapSequenceCoordinator")) "仍使用自建点击协调器"
    检查 (-not $原生容器文本.Contains("DispatchQueue.main.asyncAfter")) "仍使用自建点击计时器"

    检查 ($标定文本.Contains("S2Geometry.isScreenAspectMatch")) "截图沉浸未复用方向归一屏幕比例判定"
    检查 ($标定文本.Contains("configuration.screenshotImmersiveOnHide")) "隐藏态未接入截图沉浸开关"
    检查 ($标定文本.Contains("presentationState.interfaceVisibility == .hidden")) "截图沉浸未按界面隐藏态裁决"
    检查 ($原生容器文本.Contains("UIView.animate(")) "截图沉浸缺少 UIKit 过渡动画"
    检查 ($原生容器文本.Contains("S2AnimationPolicy(configuration: configuration)")) "截图沉浸动画未使用统一动画参数"
    检查 ($原生容器文本.Contains("UIView.performWithoutAnimation")) "关闭动画时未直接切换截图呈现"
    检查 ($标定文本.Contains("doubleTapTargetScale: applies")) "双击目标不再使用框显照片既有分类"
    检查 ($标定文本.Contains("aspectFillMultiplier: fillMultiplier")) "填满倍数基准被改动"

    检查 (-not $原生容器文本.Contains("onPhotoSwitch")) "分页控制器仍持有触觉或换片回调"
    检查 ($视图文本.Contains("source == .bottomStripDrag")) "触觉策略未限定为缩略图拖动来源"
    检查 ($视图文本.Contains("source: .bottomStripDrag")) "缩略图变化未接入触觉来源"
    检查 ($视图文本.Contains("case nativePaging")) "触觉策略缺少分页拒绝来源"
    检查 ($视图文本.Contains("UISelectionFeedbackGenerator")) "未使用 selection 类触觉"

    $允许文件 = @(
        "PhotoCleanupMVE/Core/S2StateMachine.swift",
        "PhotoCleanupMVE/Features/S2/S2Calibration.swift",
        "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift",
        "PhotoCleanupMVE/Features/S2/S2View.swift",
        "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift",
        "Scripts/verify-IC-20260815-060.ps1",
        "selfcheck_IC-060_report.md"
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

    $调试定义 = @(Select-String -LiteralPath (Join-Path $项目根 "PhotoCleanupMVE/App/CleanupCoordinator.swift") -Pattern 'static\s+let\s+debugAssetLimit\s*=\s*300')
    检查 ($调试定义.Count -eq 1) "debugAssetLimit 被改动"
    $报告存在 = Test-Path -LiteralPath (Join-Path $项目根 "selfcheck_IC-060_report.md") -PathType Leaf
    检查 $报告存在 "缺少 IC-060 自验报告"
    if ($报告存在) {
        $报告文本 = 读取 "selfcheck_IC-060_report.md"
        检查 (-not [regex]::IsMatch($报告文本, '__[A-Z0-9_]+__')) "IC-060 自验报告仍含待回填占位符"
    }

    git diff --check $继承提交
    检查 ($LASTEXITCODE -eq 0) "git diff --check 失败"
    & (Join-Path $项目根 "Scripts/selfcheck.ps1")
    检查 ($LASTEXITCODE -eq 0) "仓库结构自验失败"

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
    Write-Host "IC-060 自验失败：$($失败.Count) 项失败，共执行 $检查数 项检查。" -ForegroundColor Red
    exit 1
}

$XCTest说明 = if ($执行XCTest) { "，并已执行 XCTest" } else { "；未请求执行 XCTest" }
Write-Host "IC-060 本地自验通过：共执行 $检查数 项检查，静态 XCTest 总数 $($全部测试.Count)$XCTest说明。" -ForegroundColor Green
exit 0
