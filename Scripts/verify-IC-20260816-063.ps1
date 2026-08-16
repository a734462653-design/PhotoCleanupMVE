param(
    [switch]$执行XCTest,
    [switch]$允许待回填CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$继承提交 = "456c93d1ccc0e8a91b8188a9322614ea0205b156"
$主干提交 = "bccc2d2deadf37da470b9270f25ecb0312e6d4de"
$目标分支 = "feature/ic-063-immersive-fullscreen"
$规格哈希 = "CEAE2A0FA830C26E3C6E2B70C2308081C8336720B20770E776E3F3091F80AD45"
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

function 提取出厂配置块 {
    param([string]$文本)
    $匹配 = [regex]::Match(
        $文本,
        '(?s)static let factoryPlaceholder = S2CalibrationConfiguration\((.*?)\r?\n    \)'
    )
    if (-not $匹配.Success) {
        return $null
    }
    return $匹配.Groups[1].Value
}

Push-Location $项目根
try {
    git merge-base --is-ancestor $继承提交 HEAD
    检查 ($LASTEXITCODE -eq 0) "当前提交未继承 IC-061 交付版本"
    检查 ((git branch --show-current) -eq $目标分支) "当前分支不是 IC-063 独立分支"
    检查 ((git rev-parse main) -eq $主干提交) "本地主干出现新提交"
    检查 ((git rev-parse origin/main) -eq $主干提交) "远端跟踪主干出现新提交"

    $规格路径 = Join-Path $项目根 "..\SPEC-S2-20260816_v14.md"
    检查 (Test-Path -LiteralPath $规格路径 -PathType Leaf) "缺少上游 v14 规格证据"
    if (Test-Path -LiteralPath $规格路径 -PathType Leaf) {
        $实际规格哈希 = (Get-FileHash -Algorithm SHA256 -LiteralPath $规格路径).Hash
        检查 ($实际规格哈希 -eq $规格哈希) "上游 v14 规格 SHA-256 不匹配"
    }

    $测试文件 = Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVETests") -Filter "*.swift" -File
    $全部测试 = @(Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+test')
    检查 ($全部测试.Count -eq 369) "XCTest 静态总数应为 369，实际为 $($全部测试.Count)"

    $专项测试 = 读取 "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift"
    $六项 = @(
        "testY1StatusBarTracksHiddenAndVisibleInterfaceStates",
        "testY2MatchedPhotoHiddenDisplayStrictlyEqualsViewportAndHasZeroRadius",
        "testY3NonMatchingPhotoGeometryRemainsUnchangedInBothVisibilityStates",
        "testY4DoubleTapExitUsesSingleNativeMinimumZoomAnimationWithoutOffsetWrite",
        "testY5PinchSnapBackUsesSameSingleNativeMinimumZoomAnimationPath",
        "testY6ZoomExitCompletionNormalizesStateAndAppliesCurrentPresentation"
    )
    foreach ($测试名 in $六项) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少 IC-063 XCTest：$测试名"
    }
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testY[1-6]')).Count -eq 6) "Y1 至 Y6 数量不正确"

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
        检查 ($专项测试.Contains("func $测试名(")) "缺少 IC-061 回归 XCTest：$测试名"
    }
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testX[1-8]')).Count -eq 8) "X1 至 X8 数量不正确"
    检查 ($专项测试.Contains("func testIC061NxPinchEndedStillUpdatesImageRequestWithoutPresentationChange(")) "缺少 IC-061 Nx 图像请求回归"

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
        检查 ($专项测试.Contains("func $测试名(")) "缺少更早指定回归 XCTest：$测试名"
    }

    $删除测试 = @(git diff --unified=0 $继承提交 -- PhotoCleanupMVETests | Select-String -Pattern '^-\s*func\s+test')
    检查 ($删除测试.Count -eq 0) "存在被删除的既有 XCTest，疑似静默删除"

    $标定文本 = 读取 "PhotoCleanupMVE/Features/S2/S2Calibration.swift"
    $基线标定文本 = git show "$继承提交`:PhotoCleanupMVE/Features/S2/S2Calibration.swift"
    $当前出厂块 = 提取出厂配置块 $标定文本
    $基线出厂块 = 提取出厂配置块 ($基线标定文本 -join "`n")
    检查 ($null -ne $当前出厂块) "无法提取当前出厂配置块"
    检查 ($null -ne $基线出厂块) "无法提取 IC-061 出厂配置块"
    检查 ($当前出厂块 -eq $基线出厂块) "出厂参数或策略与 IC-061 不一致"
    检查 ($标定文本.Contains('("taskID", "IC-20260816-063-immersive-fullscreen-and-zoomout")')) "参数导出任务标识不是 IC-063"
    检查 ([regex]::IsMatch($标定文本, '(?s)let displaySize = fillsViewport\s*\? physicalSize')) "命中照片隐藏态未直接采用物理视口尺寸"

    $视图文本 = 读取 "PhotoCleanupMVE/Features/S2/S2View.swift"
    检查 ($视图文本.Contains(".statusBarHidden(statusBarHidden)")) "S2 未向系统声明状态栏显隐"
    检查 ($视图文本.Contains("applyStatusBarAppearance(for: visibility)")) "状态栏未随界面显隐变化"
    检查 ($视图文本.Contains("duration: appearance.transitionDuration")) "状态栏未使用界面显隐过渡时长"

    $原生容器文本 = 读取 "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
    检查 ($原生容器文本.Contains("scaleX: targetFrame.scaleX")) "沉浸过渡未覆盖横向目标尺寸"
    检查 ($原生容器文本.Contains("y: targetFrame.scaleY")) "沉浸过渡未覆盖纵向目标尺寸"
    检查 (([regex]::Matches($原生容器文本, 'setZoomScale\(minimumZoomScale,\s*animated:\s*true\)')).Count -eq 1) "原生最小倍率动画调用不是唯一单次入口"
    检查 (([regex]::Matches($原生容器文本, 'returnToMinimumZoomScale\(on: page\)')).Count -eq 2) "双击退出与捏合归位未共用统一入口"
    $统一入口 = [regex]::Match(
        $原生容器文本,
        '(?s)func animateToMinimumZoomScale\(\) \{.*?\r?\n    \}'
    )
    检查 ($统一入口.Success) "缺少原生最小倍率统一入口"
    if ($统一入口.Success) {
        检查 ($统一入口.Value.Contains("setZoomScale(minimumZoomScale, animated: true)")) "统一入口未调用原生 setZoomScale 动画"
        检查 (-not $统一入口.Value.Contains("contentOffset")) "统一入口中存在独立 contentOffset 写入"
    }
    检查 ($原生容器文本.Contains("independentContentOffsetWriteCount")) "缺少独立偏移写入诊断计数"
    检查 ($专项测试.Contains("visible.oneXDisplaySize.width * targetFrame.scaleX")) "Y2 未锁定横向动画终点"
    检查 ($专项测试.Contains("visible.oneXDisplaySize.height * targetFrame.scaleY")) "Y2 未锁定纵向动画终点"
    检查 (-not $专项测试.Contains("XCTAssertEqual(hidden.oneXDisplaySize, hidden.aspectFitSize)")) "IC-060 S2 失效子断言仍未替换"

    $允许文件 = @(
        "PhotoCleanupMVE/Features/S2/S2Calibration.swift",
        "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift",
        "PhotoCleanupMVE/Features/S2/S2View.swift",
        "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift",
        "Scripts/verify-IC-20260816-063.ps1",
        "selfcheck_IC-063_report.md"
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
    检查 (-not ($变更文件 | Where-Object { $_ -match '^PhotoCleanupMVE/Features/S[1345]/' })) "出现 S1、S3、S4 或 S5 源码变更"

    $调试定义 = @(Select-String -LiteralPath (Join-Path $项目根 "PhotoCleanupMVE/App/CleanupCoordinator.swift") -Pattern 'static\s+let\s+debugAssetLimit\s*=\s*300')
    检查 ($调试定义.Count -eq 1) "debugAssetLimit 被改动"

    $报告路径 = Join-Path $项目根 "selfcheck_IC-063_report.md"
    $报告存在 = Test-Path -LiteralPath $报告路径 -PathType Leaf
    检查 $报告存在 "缺少 IC-063 自验报告"
    if ($报告存在) {
        $报告文本 = 读取 "selfcheck_IC-063_report.md"
        检查 ($报告文本.Contains("填满计算基准取错")) "报告未写明第 2 条根因分类"
        检查 ($报告文本.Contains("IC-060 S2")) "报告未列出 IC-060 S2 失效子断言"
        检查 ($报告文本.Contains("既有 L7")) "报告未列出 L7 任务标识替代断言"
        检查 ($报告文本.Contains("X1～X8 均未失效")) "报告未声明 IC-061 X1～X8 的有效性"
        检查 ($报告文本.Contains("369")) "报告未记录测试总数 369"
        if (-not $允许待回填CI) {
            检查 (-not [regex]::IsMatch($报告文本, '__[A-Z0-9_]+__')) "报告仍含 CI 或 IPA 待回填占位符"
            检查 ([regex]::IsMatch($报告文本, 'https://github\.com/.+/actions/runs/\d+')) "报告缺少 CI run 链接"
            检查 ([regex]::IsMatch($报告文本, 'Executed 369 tests, with 0 failures')) "报告缺少 XCTest 执行原文"
            检查 ([regex]::IsMatch($报告文本, 'IPA SHA-256：`[0-9a-f]{64}`')) "报告缺少 IPA SHA-256"
        }
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
    Write-Host "IC-063 自验失败：$($失败.Count) 项失败，共执行 $检查数 项检查。" -ForegroundColor Red
    exit 1
}

$XCTest说明 = if ($执行XCTest) { "，并已执行 XCTest" } else { "；未请求执行 XCTest" }
Write-Host "IC-063 本地自验通过：共执行 $检查数 项检查，静态 XCTest 总数 $($全部测试.Count)$XCTest说明。" -ForegroundColor Green
exit 0
