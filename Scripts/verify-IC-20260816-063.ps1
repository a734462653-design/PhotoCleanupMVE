param(
    [switch]$执行XCTest,
    [switch]$允许待回填CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$继承提交 = "c6938dd0c041d7c17cac0ffb461586b9c7415a2a"
$主干提交 = "bccc2d2deadf37da470b9270f25ecb0312e6d4de"
$目标分支 = "feature/ic-063-immersive-transition"
$规格哈希 = "CEAE2A0FA830C26E3C6E2B70C2308081C8336720B20770E776E3F3091F80AD45"
$检查数 = 0
$失败 = [System.Collections.Generic.List[string]]::new()

function 检查 {
    param([bool]$条件, [string]$说明)
    $script:检查数 += 1
    if (-not $条件) {
        $script:失败.Add($说明)
    }
}

function 读取 {
    param([string]$相对路径)
    Get-Content -LiteralPath (Join-Path $项目根 $相对路径) -Raw -Encoding UTF8
}

function 读取提交文件 {
    param([string]$提交)
    @(
        git show --format= --name-only $提交 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
}

Push-Location $项目根
try {
    git merge-base --is-ancestor $继承提交 HEAD
    检查 ($LASTEXITCODE -eq 0) "当前提交未继承已完成的 IC-063 v1"
    检查 ((git branch --show-current) -eq $目标分支) "当前分支不是 v2 指定分支"
    检查 ((git rev-parse main) -eq $主干提交) "本地主干出现新提交"
    检查 ((git rev-parse origin/main) -eq $主干提交) "远端跟踪主干出现新提交"

    $规格路径 = Join-Path $项目根 "..\SPEC-S2-20260816_v14.md"
    检查 (Test-Path -LiteralPath $规格路径 -PathType Leaf) "缺少 v14 规格证据"
    if (Test-Path -LiteralPath $规格路径 -PathType Leaf) {
        检查 (
            (Get-FileHash -Algorithm SHA256 -LiteralPath $规格路径).Hash -eq
                $规格哈希
        ) "v14 规格 SHA-256 不匹配"
    }

    $手势提交 = git log --format=%H --grep="^fix: 修复 Nx 竖向手势分层回归$" -1
    检查 (-not [string]::IsNullOrWhiteSpace($手势提交)) "缺少第 0 项独立提交"
    if (-not [string]::IsNullOrWhiteSpace($手势提交)) {
        $手势文件 = @(读取提交文件 $手势提交)
        $预期手势文件 = @(
            "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift",
            "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift"
        )
        检查 (
            (@($手势文件 | Where-Object { $_ -notin $预期手势文件 })).Count -eq 0
        ) "第 0 项提交混入了其余功能文件"
        检查 (
            (@($预期手势文件 | Where-Object { $_ -notin $手势文件 })).Count -eq 0
        ) "第 0 项提交缺少源码或测试"
        git merge-base --is-ancestor $手势提交 HEAD
        检查 ($LASTEXITCODE -eq 0) "当前 HEAD 未包含第 0 项提交"
    }

    $测试文件 = Get-ChildItem -LiteralPath (
        Join-Path $项目根 "PhotoCleanupMVETests"
    ) -Filter "*.swift" -File
    $全部测试 = @(Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+test')
    检查 ($全部测试.Count -ge 363) "XCTest 静态总数低于 363，实际为 $($全部测试.Count)"

    $测试文本 = 读取 "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift"
    $专项测试 = @(
        "testIC063G1HiddenMatchedPhotoWindowFrameEqualsScreenBounds",
        "testIC063G2VisibleMatchedPhotoUsesInsetLayoutAndIsCentered",
        "testIC063G3DoubleTapTargetUsesTwoOnlyForMatchedPhotos",
        "testIC063G4DoubleTapSynchronizationPreservesWindowFrameBothWays",
        "testIC063G5NxVisibilityTogglePreservesNativeGeometryAndCorner",
        "testIC063G6NxDeferredPresentationCommitsExactlyOnceOnExit",
        "testIC063G7AllPhotoScrollViewsReadBackNeverAdjustment",
        "testIC063G8NativePagerStillUsesOriginalStateMachineInstance",
        "testG9NxSwipeUpLeavesDeletionSetAndCurrentIndexUnchanged",
        "testG10NxSwipeDownLeavesDeletionSetAndCurrentIndexUnchanged",
        "testG11NxVerticalPanChangesContentOffsetWithinNativeBounds",
        "testG12PinchSnapBackImmediatelyRestoresSwipeUpMarking",
        "testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages"
    )
    foreach ($测试名 in $专项测试) {
        检查 ($测试文本.Contains("func $测试名(")) "缺少 XCTest：$测试名"
    }
    检查 (-not $测试文本.Contains("testG2NxSwipeUpMarksCurrentAsset")) "仍保留 Nx 上滑标记的冲突断言"
    检查 ($测试文本.Contains("let nearToleranceRatio = screenAspectRatio * 1.009")) "G2 未覆盖容差内但比例不完全相等的照片"

    $原生文本 = 读取 "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
    检查 ($原生文本.Contains("return machine.scale == 1")) "竖向识别器没有按严格 s == 1 门控"
    检查 ($原生文本.Contains("shouldBeginVerticalSwipe(for: velocity)")) "门控未放在 shouldBegin 入口"
    检查 ($原生文本.Contains("S2DoubleTapTransitionView")) "缺少双击专用过渡层"
    检查 ($原生文本.Contains("isDoubleTapTransitionActive")) "缺少双击过渡状态门控"
    检查 ($原生文本.Contains("S2DoubleTapSynchronizationReading")) "缺少同步前后 window frame 证据"
    检查 ($原生文本.Contains("applyDoubleTapTarget")) "双击终点未同步给 UIScrollView"
    检查 ($原生文本.Contains("!controller.isDoubleTapTransitionActive")) "父分页布局未冻结双击动画期间的原生倍率"
    检查 (-not $原生文本.Contains("presentationContentView.transform = CGAffineTransform")) "1x 沉浸仍由内层 transform 承载"
    检查 ($原生文本.Contains("contentSize = viewportSize")) "1x contentSize 未固定为视口"
    检查 ($原生文本.Contains("setContentOffset(.zero, animated: false)")) "1x contentOffset 未归零"
    检查 (([regex]::Matches($原生文本, 'contentInsetAdjustmentBehavior = \.never')).Count -ge 2) "内外滚动视图未显式设置 .never"
    检查 ($原生文本.Contains("hostingController.additionalSafeAreaInsets = .zero")) "内层 HostingController 未清空额外安全区"
    检查 ($原生文本.Contains("page.content.ignoresSafeArea()")) "内层照片托管根未真正忽略安全区"
    检查 ($原生文本.Contains("S2GeometryDiagnosticsRun")) "缺少自动几何诊断执行器"
    foreach ($题号 in 1..4) {
        检查 ($原生文本.Contains("Q$题号" + "：")) "诊断报告缺少 Q$题号 回答"
    }
    检查 ($原生文本.Contains("verticalSwipeRecognizer.state.rawValue")) "诊断未记录竖向识别器状态"
    检查 ($原生文本.Contains("minimumMiddleFrames: 3")) "进入动画未要求至少 3 个中间帧"
    检查 ($原生文本.Contains("minimumMiddleFrames: 5")) "退出动画未要求至少 5 个中间帧"
    检查 (-not $原生文本.Contains("let safeContribution: CGFloat = 0")) "诊断仍把安全区贡献硬编码为零"

    $标定文本 = 读取 "PhotoCleanupMVE/Features/S2/S2Calibration.swift"
    检查 ([regex]::IsMatch($标定文本, 'minDoubleTapScale:\s*2,')) "minDoubleTapScale 出厂值不是 2.000000"
    检查 ([regex]::IsMatch($标定文本, 'fitInsetRatio:\s*0\.30,')) "fitInsetRatio 出厂值不再是 0.300000"
    检查 ([regex]::IsMatch($标定文本, 'fitCornerRadius:\s*28,')) "fitCornerRadius 出厂值被改动"
    检查 ([regex]::IsMatch($标定文本, 'pinchMaxScale:\s*4,')) "pinchMaxScale 被改动"
    检查 ($标定文本.Contains("nativeZoomBaseSize: applies ? physicalSize : fitSize")) "Nx 未使用去内缩后的几何基准"
    检查 ($标定文本.Contains("(applies && matchesScreenAspect)")) "命中容差的 1x 手机框未以物理视口为尺寸基准"

    $视图文本 = 读取 "PhotoCleanupMVE/Features/S2/S2View.swift"
    检查 ($视图文本.Contains('title: "fitInsetRatio"')) "debug 面板缺少 fitInsetRatio"
    检查 ($视图文本.Contains("geometryDiagnostics.export()")) "debug 面板缺少诊断入口"
    检查 ($视图文本.Contains(".ignoresSafeArea()")) "主图根视图未忽略安全区"
    检查 ($视图文本.Contains(".statusBarHidden(statusBarHidden)")) "状态栏未按 V 链路控制"

    git diff --quiet $继承提交 -- "PhotoCleanupMVE/Core/S2StateMachine.swift"
    检查 ($LASTEXITCODE -eq 0) "禁止改动的 S2StateMachine 出现差异"

    $变更文件 = @(
        git diff --name-only $继承提交
        git ls-files --others --exclude-standard
    ) | Sort-Object -Unique
    $禁止文件 = @($变更文件 | Where-Object {
        [System.IO.Path]::GetFileName($_) -like "SPEC-*.md" -or
            [System.IO.Path]::GetFileName($_) -eq "Decision_log.md" -or
            $_ -match '^PhotoCleanupMVE/Features/S[1345]/'
    })
    检查 ($禁止文件.Count -eq 0) "变更清单含禁止文件：$($禁止文件 -join ', ')"
    $允许前缀 = @(
        "PhotoCleanupMVE/App/CleanupCoordinator.swift",
        "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift",
        "PhotoCleanupMVE/Features/S2/",
        "PhotoCleanupMVE/Localizable.xcstrings",
        "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift",
        "Scripts/scan-hardcoded-user-visible-strings.ps1",
        "Scripts/verify-IC-20260816-063.ps1",
        "Reports/IC-063/",
        "selfcheck_IC-063_report.md"
    )
    $范围外文件 = @($变更文件 | Where-Object {
        $文件 = $_
        -not ($允许前缀 | Where-Object { $文件.StartsWith($_) })
    })
    检查 ($范围外文件.Count -eq 0) "存在范围外变更：$($范围外文件 -join ', ')"

    $调试定义 = @(Select-String -LiteralPath (
        Join-Path $项目根 "PhotoCleanupMVE/App/CleanupCoordinator.swift"
    ) -Pattern 'static\s+let\s+debugAssetLimit\s*=\s*300')
    检查 ($调试定义.Count -eq 1) "debugAssetLimit 被改动"

    $自验路径 = Join-Path $项目根 "Reports/IC-063/self-check.md"
    $样例路径 = Join-Path $项目根 "Reports/IC-063/diagnostics-sample.md"
    检查 (Test-Path -LiteralPath $自验路径 -PathType Leaf) "缺少 self-check.md"
    检查 (Test-Path -LiteralPath $样例路径 -PathType Leaf) "缺少 diagnostics-sample.md"
    if ((Test-Path -LiteralPath $自验路径) -and -not $允许待回填CI) {
        $报告 = Get-Content -LiteralPath $自验路径 -Raw -Encoding UTF8
        检查 (-not [regex]::IsMatch($报告, '__[A-Z0-9_]+__')) "自验报告仍含待回填占位符"
        检查 ([regex]::IsMatch($报告, 'CI\s*#\d+')) "自验报告缺少 CI 编号"
        检查 ([regex]::IsMatch($报告, 'Executed\s+\d+\s+tests, with 0 failures')) "自验报告缺少 XCTest 实跑原文"
        检查 ($报告.Contains("真实退出码：0")) "自验报告未记录真实退出码 0"
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
            检查 ($LASTEXITCODE -eq 0) "XCTest 真实退出码非 0"
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
    Write-Host "IC-063 v2 自验失败：$($失败.Count) 项失败，共执行 $检查数 项检查。" -ForegroundColor Red
    exit 1
}

$XCTest说明 = if ($执行XCTest) { "，并已执行 XCTest" } else { "；未请求执行 XCTest" }
Write-Host "IC-063 v2 本地自验通过：共执行 $检查数 项检查，静态 XCTest 总数 $($全部测试.Count)$XCTest说明。" -ForegroundColor Green
exit 0
