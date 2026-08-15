param(
    [switch]$执行XCTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$继承提交 = "cc95139"
$主干提交 = "bccc2d2deadf37da470b9270f25ecb0312e6d4de"
$目标分支 = "feature/ic-059-regression-and-framing"
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
    检查 ($LASTEXITCODE -eq 0) "当前提交不包含已审计的 IC-058 继承提交"
    检查 ((git branch --show-current) -eq $目标分支) "当前分支不是 IC-059 独立分支"
    检查 ((git rev-parse main) -eq $主干提交) "本地主干出现新提交"
    检查 ((git rev-parse origin/main) -eq $主干提交) "远端跟踪主干出现新提交"

    $测试文件 = Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVETests") -Filter "*.swift" -File
    $全部测试 = @(Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+test')
    检查 ($全部测试.Count -ge 341) "XCTest 静态总数少于 341，实际为 $($全部测试.Count)"

    $专项测试 = 读取 "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift"
    $十五项 = @(
        "testG1OneXSwipeUpMarksCurrentAsset",
        "testG2NxSwipeUpMarksCurrentAsset",
        "testG3NativeSecondTapRevertsSingleAndMatchesDirectDoubleTap",
        "testG4TwoNativeSingleTapsOutsideWindowToggleTwiceWithoutZoom",
        "testM1ScreenAspectDoubleTapUsesMinimumScale",
        "testM2NonScreenPhotoDoubleTapUsesAspectFillScale",
        "testF1FactoryInsetShrinksShortEdgeToSeventyPercent",
        "testF2CornerRadiusAppliesOnlyToInsetPhotos",
        "testF3InterfaceVisibilityKeepsOneXFrameAndCornerRadiusEqual",
        "testF4InsetDoesNotChangeViewportOrAspectFillMultiplier",
        "testB1NxBoundaryContinuationProducesPagingDisplacement",
        "testB2NxBoundaryPagingBelowThresholdKeepsCurrentIndex",
        "testB3NxBoundaryPagingCompletionResetsNewPhotoScale",
        "testH1EnabledPhotoSwitchHapticFiresOncePerSuccessfulSwitch",
        "testH2DisabledPhotoSwitchHapticDoesNotFire"
    )
    foreach ($测试名 in $十五项) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少 IC-059 XCTest：$测试名"
    }
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testG[1-4]')).Count -eq 4) "G1 至 G4 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testM[1-2]')).Count -eq 2) "M1 至 M2 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testF[1-4]')).Count -eq 4) "F1 至 F4 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testB[1-3]')).Count -eq 3) "B1 至 B3 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testH[1-2]')).Count -eq 2) "H1 至 H2 数量不正确"

    $回归测试名 = @(
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
        "testD1ReplacementScreenAspectFitInsetShrinksShortEdgeToSeventyPercent",
        "testD2ZeroFitInsetMatchesPureAspectFit",
        "testD3ScreenAspectOnlyLeavesNonScreenPhotoUnchanged",
        "testD4ScreenAspectDoubleTapUsesMinimumScale",
        "testD5ReplacementNonScreenDoubleTapUsesAspectFillScale",
        "testD6LeftEdgeDoubleTapAlignsLeftContentBoundary",
        "testD7RightTopAndBottomEdgeDoubleTapAlignsEachBoundary",
        "testD8DoubleTapExitResetsScaleAndOffset"
    )
    foreach ($测试名 in $回归测试名) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少指定回归 XCTest：$测试名"
    }
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testN[1-8]')).Count -eq 8) "N1 至 N8 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testE[1-6]')).Count -eq 6) "E1 至 E6 数量不正确"
    检查 (([regex]::Matches($专项测试, '(?m)^\s*func\s+testD[1-8]')).Count -eq 8) "D1 至 D8 数量不正确"

    $标定文本 = 读取 "PhotoCleanupMVE/Features/S2/S2Calibration.swift"
    $原生容器文本 = 读取 "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
    $视图文本 = 读取 "PhotoCleanupMVE/Features/S2/S2View.swift"
    $状态机文本 = 读取 "PhotoCleanupMVE/Core/S2StateMachine.swift"
    $状态机测试文本 = 读取 "PhotoCleanupMVETests/S2StateMachineTests.swift"

    检查 ([regex]::IsMatch($标定文本, 'fitInsetRatio:\s*0\.30,')) "fitInsetRatio 出厂值不是 0.30"
    检查 ([regex]::IsMatch($标定文本, 'fitCornerRadius:\s*28,')) "fitCornerRadius 出厂值不是 28"
    检查 ([regex]::IsMatch($标定文本, 'minDoubleTapScale:\s*2\.5,')) "minDoubleTapScale 出厂值不是 2.5"
    检查 ([regex]::IsMatch($标定文本, 'hapticOnPhotoSwitch:\s*true,')) "hapticOnPhotoSwitch 出厂值不是 true"
    检查 ($标定文本.Contains('("fitCornerRadius", formatted(fitCornerRadius))')) "参数导出缺少 fitCornerRadius"
    检查 ($标定文本.Contains('("hapticOnPhotoSwitch", String(hapticOnPhotoSwitch))')) "参数导出缺少 hapticOnPhotoSwitch"
    检查 ($标定文本.Contains('? CGFloat(configuration.minDoubleTapScale)') -and $标定文本.Contains(': fillMultiplier')) "双击目标未按类别二选一"
    检查 (-not $状态机文本.Contains("max(calculatedMultiplier, parameters.minDoubleTapScale)")) "状态机残留双击一刀切规则"
    检查 ($标定文本.Contains("S2Geometry.isScreenAspectMatch")) "布局未复用方向归一的屏幕比例判定"
    检查 ($标定文本.Contains("let oneXCornerRadius: CGFloat")) "布局读数缺少圆角半径"

    检查 ($原生容器文本.Contains("let singleTapRecognizer = UITapGestureRecognizer()")) "缺少原生单击识别器"
    检查 ($原生容器文本.Contains("let doubleTapRecognizer = UITapGestureRecognizer()")) "缺少原生双击识别器"
    检查 ($原生容器文本.Contains("shouldRecognizeSimultaneouslyWith")) "单击与双击未交给原生同时识别裁决"
    检查 ($原生容器文本.Contains("shouldReceive touch: UITouch")) "单击识别器未在原生 delegate 层接收触点"
    检查 ($原生容器文本.Contains("allowsSingleTap(tapCount: touch.tapCount)")) "第二击未使用 UIKit tapCount 从单击识别器排除"
    检查 (-not $原生容器文本.Contains("S2TapSequenceCoordinator")) "仍使用自建点击协调器"
    检查 (([regex]::Matches($原生容器文本, 'require\(\s*toFail:\s*verticalSwipeRecognizer')).Count -eq 2) "竖向手势与两层原生滚动的优先级未显式声明"
    检查 ($原生容器文本.Contains("S2NxEdgePagingInteraction")) "缺少 Nx 边界溢出分页"
    检查 ($原生容器文本.Contains("projection.overflowDistance")) "Nx 分页未使用越界继续拖动距离"
    检查 ($原生容器文本.Contains("layer.cornerRadius = max(0, cornerRadius)")) "原生内容未应用圆角裁切"
    检查 ($状态机文本.Contains("func handleSwipeUp() -> Bool")) "状态机缺少上滑入口"
    检查 ($状态机测试文本.Contains("testIC059NxSwipeUpMarksAndResetsAfterPhotoChange")) "旧 Nx 禁止标记断言未替换"
    检查 ($视图文本.Contains("UISelectionFeedbackGenerator")) "未使用 selection 类触觉"
    检查 ($视图文本.Contains("calibrationBinding(\.hapticOnPhotoSwitch)")) "触觉参数未接入面板"
    检查 ($视图文本.Contains("calibrationBinding(\.fitCornerRadius)")) "圆角参数未接入面板"

    $允许文件 = @(
        "PhotoCleanupMVE/Core/S2StateMachine.swift",
        "PhotoCleanupMVE/Features/S2/S2Calibration.swift",
        "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift",
        "PhotoCleanupMVE/Features/S2/S2View.swift",
        "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift",
        "PhotoCleanupMVETests/S2StateMachineTests.swift",
        "Scripts/verify-IC-20260815-059.ps1",
        "selfcheck_IC-059_report.md"
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
    检查 (Test-Path -LiteralPath (Join-Path $项目根 "selfcheck_IC-059_report.md") -PathType Leaf) "缺少 IC-059 自验报告"

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
    Write-Host "IC-059 自验失败：$($失败.Count) 项失败，共执行 $检查数 项检查。" -ForegroundColor Red
    exit 1
}

$XCTest说明 = if ($执行XCTest) { "，并已执行 XCTest" } else { "；未请求执行 XCTest" }
Write-Host "IC-059 本地自验通过：共执行 $检查数 项检查，静态 XCTest 总数 $($全部测试.Count)$XCTest说明。" -ForegroundColor Green
exit 0
