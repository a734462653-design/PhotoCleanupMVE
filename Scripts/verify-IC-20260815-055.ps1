param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$基线提交 = "16c03234f96f12af10843b1df2602214f2e71a74"
$目标分支 = "feature/ic-055-usable-build"
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
    git merge-base --is-ancestor $基线提交 HEAD
    检查 ($LASTEXITCODE -eq 0) "当前提交不包含 IC-054 上游基线"
    检查 ((git branch --show-current) -eq $目标分支) "当前分支不是指定独立分支"

    $测试文件 = Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVETests") -Filter "*.swift" -File
    $全部测试 = @(Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+test')
    检查 ($全部测试.Count -ge 295) "XCTest 静态总数少于 295，实际为 $($全部测试.Count)"

    $专项测试 = 读取 "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift"
    $预期测试名 = @(
        "testL1TopOverlayFramesRespectSafeAreaTop",
        "testL2BottomOverlayFramesRespectHomeIndicator",
        "testL3TopOverlayFramesDoNotIntersect",
        "testL4ClickableOverlayControlsMeetMinimumTouchTarget",
        "testL5CalibrationPanelsDoNotChangeViewportSize",
        "testL6CalibrationPanelsStartHiddenWithoutVisibleEntry",
        "testL7FactoryDefaultsMatchUsableBuildDecision",
        "testV1InterfaceVisibilityKeepsViewportSizeEqual",
        "testV2BottomStripStatesKeepViewportSizeAndHeightEqual",
        "testV3SheetPresentationKeepsViewportSizeEqual",
        "testV4AllPresentationStatesShareFitAndDoubleTapMultiplier",
        "testV5ParametersSurviveProcessModelRestart",
        "testV6AllFourImageRequestStrategiesTakeEffectImmediately",
        "testV7MissingAspectCategoryReturnsExplicitEmptyResult",
        "testV8FitInsetRatioGeometryAndScopeAreCorrect"
    )
    foreach ($测试名 in $预期测试名) {
        检查 ($专项测试.Contains("func $测试名(")) "缺少专项 XCTest：$测试名"
    }
    $L方法数 = ([regex]::Matches($专项测试, '(?m)^\s*func\s+testL[1-7]')).Count
    $V方法数 = ([regex]::Matches($专项测试, '(?m)^\s*func\s+testV[1-8]')).Count
    检查 ($L方法数 -eq 7) "L1 至 L7 应恰有 7 个测试，实际为 $L方法数"
    检查 ($V方法数 -eq 8) "V1 至 V8 应恰有 8 个测试，实际为 $V方法数"

    $标定文本 = 读取 "PhotoCleanupMVE/Features/S2/S2Calibration.swift"
    $视图文本 = 读取 "PhotoCleanupMVE/Features/S2/S2View.swift"
    $目录文本 = 读取 "PhotoCleanupMVE/Localizable.xcstrings"

    检查 ([regex]::IsMatch($标定文本, 'fitInsetRatio:\s*0\.05,')) "fitInsetRatio 默认值不是 0.05"
    检查 ([regex]::IsMatch($标定文本, 'fitInsetScope:\s*\.screenAspectOnly')) "fitInsetScope 默认值不正确"
    检查 ([regex]::IsMatch($标定文本, 'animationsEnabled:\s*true,')) "animationsEnabled 默认值不是 true"
    检查 ([regex]::IsMatch($标定文本, 'animationDurationMilliseconds:\s*220,')) "动画时长默认值不是 220"
    检查 ([regex]::IsMatch($标定文本, 'verticalSwipeDistance:\s*40,')) "竖滑距离默认值不是 40"
    检查 ([regex]::IsMatch($标定文本, 'verticalSwipeVelocity:\s*100,')) "竖滑速度默认值不是 100"
    检查 ([regex]::IsMatch($标定文本, 'scaleChangeRequestPolicy:\s*\.everyScaleChange')) "缩放请求策略默认值不正确"
    检查 ([regex]::IsMatch($标定文本, 'degradedPreviewPolicy:\s*\.finalImageOnly')) "降质预览策略默认值不正确"
    检查 ($标定文本.Contains('taskID", "IC-20260815-055-s2-usable-build')) "参数导出任务标识未更新"
    检查 ($目录文本.Contains('"value" : "④项目判断默认值，可修订"')) "参数状态标签不正确"
    检查 (-not $目录文本.Contains('未标定：以下值均为出厂占位值或人工调参值')) "仍保留旧未标定标签"
    检查 ($目录文本.Contains('"value" : "核心手感参数，优先调整"')) "缺少核心手感参数标注"

    $竖滑距离位置 = $视图文本.IndexOf('title: "verticalSwipeDistance"')
    $竖滑速度位置 = $视图文本.IndexOf('title: "verticalSwipeVelocity"')
    $请求策略位置 = $视图文本.IndexOf('"scaleChangeRequestPolicy"')
    检查 ($竖滑距离位置 -ge 0 -and $竖滑距离位置 -lt $请求策略位置) "竖滑距离没有置于面板顶部"
    检查 ($竖滑速度位置 -gt $竖滑距离位置 -and $竖滑速度位置 -lt $请求策略位置) "竖滑速度没有置于面板顶部"

    $不再标定字段 = @(
        "pinchMaxScale",
        "zoomSnapBackThreshold",
        "doubleTapAnchorStrategy",
        "edgePagingTriggerDistance",
        "edgePagingTriggerVelocity",
        "horizontalSwipeDistance",
        "horizontalSwipeVelocity",
        "horizontalSwipeMaximumDurationMilliseconds",
        "pinchMinimumScaleDelta",
        "pinchMinimumVelocityPerSecond",
        "pinchMaximumDurationMilliseconds",
        "mainDragMinimumDistance",
        "mainDragMinimumVelocity",
        "mainDragMaximumDurationMilliseconds",
        "singleTapMaximumMovement",
        "singleTapMaximumDurationMilliseconds",
        "singleTapDecisionWindowMilliseconds",
        "doubleTapDecisionWindowMilliseconds",
        "singleTapTouchCount",
        "doubleTapTouchCount",
        "singleDragTouchCount",
        "pinchTouchCount",
        "gestureExclusivityPolicy"
    )
    foreach ($字段 in $不再标定字段) {
        检查 (-not $视图文本.Contains("calibrationBinding(\.$字段)")) "已定字段仍出现在调参范围：$字段"
    }

    检查 ($视图文本.Contains("S2SafeAreaInsetsReader")) "浮层没有读取系统安全区"
    检查 ($视图文本.Contains("S2TopBarLayout")) "顶部元素没有使用明确布局"
    检查 ($视图文本.Contains("S2OverlayLayout.minimumTouchTarget")) "缺少 44 pt 触达约束接线"
    检查 ($视图文本.Contains("LongPressGesture")) "缺少无布局占位的后台长按入口"
    检查 ($标定文本.Contains("calibrationEntryFrame: nil")) "后台入口仍占据主界面布局"
    检查 ($标定文本.Contains("static let initial = S2CalibrationOverlayState")) "缺少面板默认关闭状态"
    检查 ($视图文本.Contains(".ignoresSafeArea()")) "主图根视图未保持全屏物理边界"

    $基线视图 = git show "${基线提交}:PhotoCleanupMVE/Features/S2/S2View.swift" | Out-String
    $当前材质数 = ([regex]::Matches($视图文本, '\.background\(\.regularMaterial\)')).Count
    $基线材质数 = ([regex]::Matches($基线视图, '\.background\(\.regularMaterial\)')).Count
    检查 ($当前材质数 -eq $基线材质数) "系统材质数量发生变化"

    $视图差异 = git diff --unified=0 $基线提交 -- "PhotoCleanupMVE/Features/S2/S2View.swift"
    $新增禁改样式 = @($视图差异 | Where-Object {
        $_ -match '^\+(?!\+\+).*(foregroundStyle|foregroundColor|font|cornerRadius|clipShape|shadow)\('
    })
    检查 ($新增禁改样式.Count -eq 0) "新增了范围外视觉样式"

    $调试定义 = @(Select-String -LiteralPath (Join-Path $项目根 "PhotoCleanupMVE/App/CleanupCoordinator.swift") -Pattern 'static\s+let\s+debugAssetLimit\s*=\s*300')
    检查 ($调试定义.Count -eq 1) "debugAssetLimit 被改动"

    $允许文件 = @(
        "PhotoCleanupMVE/Features/S2/S2Calibration.swift",
        "PhotoCleanupMVE/Features/S2/S2View.swift",
        "PhotoCleanupMVE/Localizable.xcstrings",
        "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift",
        "Scripts/verify-IC-20260815-055.ps1",
        "selfcheck_IC-055_report.md"
    )
    $变更文件 = @(
        git diff --name-only $基线提交
        git ls-files --others --exclude-standard
    ) | Sort-Object -Unique
    $范围外文件 = @($变更文件 | Where-Object { $_ -notin $允许文件 })
    检查 ($范围外文件.Count -eq 0) "存在范围外变更文件：$($范围外文件 -join ', ')"
    $禁止文件 = @($变更文件 | Where-Object {
        $_ -like "SPEC-*.md" -or $_ -eq "Decision_log.md"
    })
    检查 ($禁止文件.Count -eq 0) "变更清单含禁止修改的规格或决策日志"

    git diff --check $基线提交
    检查 ($LASTEXITCODE -eq 0) "git diff --check 失败"

    & (Join-Path $项目根 "Scripts/selfcheck.ps1")
    检查 ($LASTEXITCODE -eq 0) "仓库结构自验失败"
    & (Join-Path $项目根 "Scripts/scan-hardcoded-user-visible-strings.ps1")
    检查 ($LASTEXITCODE -eq 0) "用户可见字符串扫描失败"
    检查 (Test-Path -LiteralPath (Join-Path $项目根 "selfcheck_IC-055_report.md") -PathType Leaf) "缺少 IC-055 自验报告"
}
finally {
    Pop-Location
}

if ($失败.Count -gt 0) {
    foreach ($项目 in $失败) {
        Write-Host "错误：$项目" -ForegroundColor Red
    }
    Write-Host "IC-055 自验失败：$($失败.Count) 项失败，共执行 $检查数 项检查。" -ForegroundColor Red
    exit 1
}

Write-Host "IC-055 本地自验通过：共执行 $检查数 项检查，静态 XCTest 总数 $($全部测试.Count)，L1 至 L7 与 V1 至 V8 均存在。" -ForegroundColor Green
exit 0
