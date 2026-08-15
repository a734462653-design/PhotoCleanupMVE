param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$基线提交 = "bccc2d2deadf37da470b9270f25ecb0312e6d4de"
$目标分支 = "feature/ic-054-calibration-harness"
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
    git merge-base --is-ancestor 3914f0a main
    检查 ($LASTEXITCODE -eq 0) "main 不包含前置提交 3914f0a"
    检查 ((git rev-parse $基线提交) -eq $基线提交) "缺少任务基线提交"
    检查 ((git branch --show-current) -eq $目标分支) "当前分支不是指定独立分支"

    $规格路径 = Join-Path (Split-Path -Parent $项目根) "SPEC-S2-20260813.v13.md"
    检查 (Test-Path -LiteralPath $规格路径 -PathType Leaf) "缺少上游 SPEC-S2 v13"
    if (Test-Path -LiteralPath $规格路径 -PathType Leaf) {
        $规格哈希 = (Get-FileHash -LiteralPath $规格路径 -Algorithm SHA256).Hash
        检查 ($规格哈希 -eq "25741959F965B8D9438F7265745D70EE60339A6865E1763BDE71912782BED1D8") "SPEC-S2 v13 哈希不匹配"
    }

    $决策路径 = Join-Path (Split-Path -Parent $项目根) "Decision_log.md"
    检查 (Test-Path -LiteralPath $决策路径 -PathType Leaf) "缺少 Decision_log.md"
    if (Test-Path -LiteralPath $决策路径 -PathType Leaf) {
        $决策文本 = Get-Content -LiteralPath $决策路径 -Raw -Encoding UTF8
        foreach ($编号 in 67..71) {
            检查 ($决策文本.Contains("### $编号.")) "Decision_log.md 缺少第 $编号 条"
        }
    }

    $测试文件 = Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVETests") -Filter "*.swift" -File
    $全部测试 = @(Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+test')
    检查 ($全部测试.Count -eq 288) "XCTest 静态总数应为 288，实际为 $($全部测试.Count)"

    $专项测试路径 = Join-Path $项目根 "PhotoCleanupMVETests/S2CalibrationHarnessTests.swift"
    检查 (Test-Path -LiteralPath $专项测试路径 -PathType Leaf) "缺少 S2 标定专项测试文件"
    if (Test-Path -LiteralPath $专项测试路径 -PathType Leaf) {
        $专项测试 = Get-Content -LiteralPath $专项测试路径 -Raw -Encoding UTF8
        $预期测试名 = @(
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
        $专项方法数 = ([regex]::Matches($专项测试, '(?m)^\s*func\s+testV[1-8]')).Count
        检查 ($专项方法数 -eq 8) "V1 至 V8 应恰有 8 个测试，实际为 $专项方法数"
    }

    $标定文本 = 读取 "PhotoCleanupMVE/Features/S2/S2Calibration.swift"
    $视图文本 = 读取 "PhotoCleanupMVE/Features/S2/S2View.swift"
    $请求文本 = 读取 "PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift"
    $状态机文本 = 读取 "PhotoCleanupMVE/Core/S2StateMachine.swift"
    $目录文本 = 读取 "PhotoCleanupMVE/Localizable.xcstrings"

    检查 ($标定文本.Contains("static let factoryPlaceholder")) "缺少单一出厂占位配置"
    检查 ([regex]::IsMatch($标定文本, 'fitInsetRatio:\s*0,')) "fitInsetRatio 出厂占位值不是 0"
    检查 ([regex]::IsMatch($标定文本, 'fitInsetScope:\s*\.screenAspectOnly')) "fitInsetRatio 出厂作用范围不正确"
    检查 ($目录文本.Contains("未标定：以下值均为出厂占位值或人工调参值，不是推荐默认值")) "面板未显式标注未标定"
    检查 ($标定文本.Contains("S2KeychainCalibrationPersistence")) "缺少耐重装钥匙串持久化"
    检查 ($标定文本.Contains("func exportText() -> String")) "缺少纯文本参数导出"
    检查 ($标定文本.Contains("func restoreFactoryPlaceholder()")) "缺少恢复出厂占位值动作"
    检查 ($视图文本.Contains(".ignoresSafeArea()")) "主图根视图未扩展到全屏物理边界"
    检查 ($视图文本.Contains(".background(.regularMaterial)")) "浮层未使用系统材质"
    检查 (-not $视图文本.Contains(".foregroundStyle(.white)")) "S2 浮层仍含本卡禁止的配色"
    检查 ($视图文本.Contains("parameterPanelVisible")) "缺少可开关调参面板"
    检查 ($视图文本.Contains("readingsVisible")) "缺少可开关实时读数"
    检查 ($状态机文本.Contains("case everyScaleChange") -and $状态机文本.Contains("case pinchEnded")) "缺少两种图像请求时机"
    检查 ($状态机文本.Contains("case display") -and $状态机文本.Contains("case finalImageOnly")) "缺少两种降质预览策略"
    检查 ($请求文本.Contains("S2ImageRequestDecision.shouldRequest")) "图像视图未使用运行时请求判定器"
    检查 ($状态机文本.Contains("func applyCalibration(")) "状态机不支持参数即时生效"
    检查 ($标定文本.Contains("enum S2AssetAspectCategory")) "缺少测试素材宽高比分类"
    检查 ($目录文本.Contains('"value" : "无此类素材"')) "缺少明确空结果文案"
    检查 ($视图文本.Contains("animationDurationMilliseconds")) "缺少动画时长运行时接线"

    $调试定义 = @(Select-String -LiteralPath (Join-Path $项目根 "PhotoCleanupMVE/App/CleanupCoordinator.swift") -Pattern 'static\s+let\s+debugAssetLimit\s*=\s*300')
    检查 ($调试定义.Count -eq 1) "debugAssetLimit 被改动"

    $变更文件 = @(
        git diff --name-only $基线提交
        git ls-files --others --exclude-standard
    ) | Sort-Object -Unique
    $禁止文件 = @($变更文件 | Where-Object {
        $_ -like "SPEC-*.md" -or $_ -eq "Decision_log.md"
    })
    检查 ($禁止文件.Count -eq 0) "变更清单含禁止修改的规格或决策日志"
    $范围外视图 = @($变更文件 | Where-Object {
        $_ -match '^PhotoCleanupMVE/Features/S[1345]/'
    })
    检查 ($范围外视图.Count -eq 0) "改动了 S1、S3、S4 或 S5 视图"

    git diff --check $基线提交
    检查 ($LASTEXITCODE -eq 0) "git diff --check 失败"

    & (Join-Path $项目根 "Scripts/selfcheck.ps1")
    检查 ($LASTEXITCODE -eq 0) "仓库结构自验失败"
    & (Join-Path $项目根 "Scripts/scan-hardcoded-user-visible-strings.ps1")
    检查 ($LASTEXITCODE -eq 0) "用户可见字符串扫描失败"

    检查 (Test-Path -LiteralPath (Join-Path $项目根 "selfcheck_IC-054_report.md") -PathType Leaf) "缺少 IC-054 自验报告"
}
finally {
    Pop-Location
}

if ($失败.Count -gt 0) {
    foreach ($项目 in $失败) {
        Write-Host "错误：$项目" -ForegroundColor Red
    }
    Write-Host "IC-054 自验失败：$($失败.Count) 项失败，共执行 $检查数 项检查。" -ForegroundColor Red
    exit 1
}

Write-Host "IC-054 本地自验通过：共执行 $检查数 项检查，静态 XCTest 总数 288，V1 至 V8 均存在。" -ForegroundColor Green
exit 0
