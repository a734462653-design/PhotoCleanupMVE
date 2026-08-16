param(
    [switch]$执行XCTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$继承提交 = "a340928ce2a088c7fe97c0c0467054eaf2f46724"
$主干提交 = "bccc2d2deadf37da470b9270f25ecb0312e6d4de"
$目标分支 = "feature/ic-061-immersive-transition"
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
    检查 ($LASTEXITCODE -eq 0) "当前提交未继承 IC-060 交付版本"
    检查 ((git branch --show-current) -eq $目标分支) "当前分支不是 IC-061 独立分支"
    检查 ((git rev-parse main) -eq $主干提交) "本地主干出现新提交"
    检查 ((git rev-parse origin/main) -eq $主干提交) "远端跟踪主干出现新提交"

    $测试文件 = Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVETests") -Filter "*.swift" -File
    $全部测试 = @(Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+test')
    检查 ($全部测试.Count -eq 362) "XCTest 静态总数应为 362，实际为 $($全部测试.Count)"

    $专项测试 = 读取 "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift"
    $八项 = @(
        "testX1ImmersiveTransitionUsesViewportCenterAnchoredScaleTransform",
        "testX2ImmersiveTransitionKeepsLayoutSizeAndUsesTransform",
        "testX3CornerRadiusInterpolatesContinuouslyInBothDirections",
        "testX4DisabledAnimationsReachEndpointWithoutTransition",
        "testX5NxVisibilityTogglePreservesAllNativeGeometry",
        "testX6NxDeferredPresentationAppliesOnceAfterReturningToOneX",
        "testX7NxExitWithoutVisibilityToggleKeepsExistingBehavior",
        "testX8ImmersiveAnimationIssuesZeroImageRequests"
    )
    foreach ($测试名 in $八项) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少 IC-061 XCTest：$测试名"
    }
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testX[1-8]')).Count -eq 8) "X1 至 X8 数量不正确"

    $上游测试 = @(
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
    foreach ($测试名 in $上游测试) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少 IC-060 回归 XCTest：$测试名"
    }

    $更早回归 = @(
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
    foreach ($测试名 in $更早回归) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少更早回归 XCTest：$测试名"
    }

    $删除测试 = @(git diff --unified=0 $继承提交 -- PhotoCleanupMVETests | Select-String -Pattern '^-\s*func\s+test')
    检查 ($删除测试.Count -eq 0) "存在被删除的既有 XCTest，疑似静默删除"

    $标定文本 = 读取 "PhotoCleanupMVE/Features/S2/S2Calibration.swift"
    $原生容器文本 = 读取 "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
    检查 ($标定文本.Contains('("taskID", "IC-20260815-061-immersive-transition-and-nx-stability")')) "参数导出任务标识不是 IC-061"
    检查 ([regex]::IsMatch($标定文本, 'animationsEnabled:\s*true,')) "animationsEnabled 出厂值被改动"
    检查 ([regex]::IsMatch($标定文本, 'animationDurationMilliseconds:\s*180,')) "动画时长出厂值被改动"
    检查 ([regex]::IsMatch($标定文本, 'fitInsetRatio:\s*0\.30,')) "fitInsetRatio 出厂值被改动"
    检查 ([regex]::IsMatch($标定文本, 'fitCornerRadius:\s*28,')) "fitCornerRadius 出厂值被改动"
    检查 ([regex]::IsMatch($标定文本, 'minDoubleTapScale:\s*2\.5,')) "minDoubleTapScale 出厂值被改动"
    检查 ([regex]::IsMatch($标定文本, 'pageSpacing:\s*20,')) "pageSpacing 出厂值被改动"
    检查 ([regex]::IsMatch($标定文本, 'doubleTapDecisionWindowMilliseconds:\s*200,')) "双击裁决参数出厂值被改动"
    检查 ([regex]::IsMatch($标定文本, 'screenshotImmersiveOnHide:\s*true,')) "截图沉浸开关出厂值被改动"

    $标定差异 = @(git diff --unified=0 $继承提交 -- PhotoCleanupMVE/Features/S2/S2Calibration.swift)
    $禁止参数差异 = @($标定差异 | Select-String -Pattern '^[+-].*(animationsEnabled|animationDurationMilliseconds|fitInsetRatio|fitCornerRadius|minDoubleTapScale|pageSpacing|doubleTapDecisionWindowMilliseconds|screenshotImmersiveOnHide|scaleChangeRequestPolicy|degradedPreviewPolicy)')
    检查 ($禁止参数差异.Count -eq 0) "IC-060 参数或图像请求策略出现差异"

    检查 ($原生容器文本.Contains("struct S2ImmersiveTransition")) "缺少沉浸过渡模型"
    检查 ($原生容器文本.Contains("presentationContentView.transform = CGAffineTransform")) "沉浸尺寸变化未由缩放变换承担"
    检查 ($原生容器文本.Contains("viewportAnchor: CGPoint(")) "未记录视口中心锚点"
    检查 ($原生容器文本.Contains("presentationContentView.layer.cornerRadius")) "圆角未进入同段动画"
    检查 ($原生容器文本.Contains("S2AnimationPolicy(configuration: configuration)")) "动画未使用统一开关与时长"
    检查 ($原生容器文本.Contains("UIView.performWithoutAnimation")) "关闭动画时没有直接切换路径"
    检查 ($原生容器文本.Contains("pendingPresentationPage")) "缺少 Nx 延迟呈现目标"
    检查 ($原生容器文本.Contains("zoomScrollView.zoomScale > 1.000_001")) "Nx 裁决未读取原生倍率"
    检查 ($原生容器文本.Contains("applyDeferredPresentationIfPossible")) "缺少回到 1x 后的延迟应用"
    检查 ($原生容器文本.Contains("presentationGeometryCommitCount")) "缺少一次性几何提交诊断"
    检查 (([regex]::Matches($原生容器文本, 'hostingController\.rootView\s*=')).Count -eq 1) "照片内容在动画提交路径之外被替换"

    $允许文件 = @(
        "PhotoCleanupMVE/Features/S2/S2Calibration.swift",
        "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift",
        "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift",
        "Scripts/verify-IC-20260815-061.ps1",
        "selfcheck_IC-061_report.md"
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

    $报告路径 = Join-Path $项目根 "selfcheck_IC-061_report.md"
    $报告存在 = Test-Path -LiteralPath $报告路径 -PathType Leaf
    检查 $报告存在 "缺少 IC-061 自验报告"
    if ($报告存在) {
        $报告文本 = 读取 "selfcheck_IC-061_report.md"
        检查 (-not [regex]::IsMatch($报告文本, '__[A-Z0-9_]+__')) "IC-061 自验报告仍含待回填占位符"
        检查 ($报告文本.Contains("IC-060 S2 控制器即时端点断言")) "报告未列出失效的 IC-060 S2 子断言"
        检查 ($报告文本.Contains("既有 L7 任务标识断言")) "报告未列出任务标识替代断言"
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
    Write-Host "IC-061 自验失败：$($失败.Count) 项失败，共执行 $检查数 项检查。" -ForegroundColor Red
    exit 1
}

$XCTest说明 = if ($执行XCTest) { "，并已执行 XCTest" } else { "；未请求执行 XCTest" }
Write-Host "IC-061 本地自验通过：共执行 $检查数 项检查，静态 XCTest 总数 $($全部测试.Count)$XCTest说明。" -ForegroundColor Green
exit 0
