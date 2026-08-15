param(
    [switch]$允许未提交交付物,
    [switch]$允许待回填CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$taskBaseline = "3ef578074e44dfc9e2fb0820b41e3730a0bb2071"
$script:checkCount = 0
$script:failures = [System.Collections.Generic.List[string]]::new()

function Add-Check {
    param(
        [bool]$Condition,
        [string]$Message
    )
    $script:checkCount += 1
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

function Read-Text {
    param([string]$RelativePath)
    Get-Content -LiteralPath (Join-Path $projectRoot $RelativePath) -Raw -Encoding UTF8
}

$requiredFiles = @(
    "PhotoCleanupMVE/App/CleanupCoordinator.swift",
    "PhotoCleanupMVE/Core/S1StateMachine.swift",
    "PhotoCleanupMVE/Services/PhotoLibraryService.swift",
    "PhotoCleanupMVETests/AlbumScopeWiringTests.swift",
    "PhotoCleanupMVE.xcodeproj/project.pbxproj",
    "Scripts/verify-IC-20260815-051.ps1"
)
foreach ($path in $requiredFiles) {
    Add-Check (
        Test-Path -LiteralPath (Join-Path $projectRoot $path) -PathType Leaf
    ) "缺少交付文件：$path"
}

$specPath = Join-Path $workspaceRoot "SPEC-S1-20260815_v6.md"
$decisionPath = Join-Path $workspaceRoot "Decision_log.md"
Add-Check (Test-Path -LiteralPath $specPath -PathType Leaf) "缺少规格输入文件"
Add-Check (Test-Path -LiteralPath $decisionPath -PathType Leaf) "缺少决策日志输入文件"
if (Test-Path -LiteralPath $specPath -PathType Leaf) {
    Add-Check (
        (Get-FileHash -LiteralPath $specPath -Algorithm SHA256).Hash -ceq
            "D43C83E6899CCDBD67543356136910424EF7C9A15908FC77315CA0A71ACE8BA0"
    ) "SPEC-S1 v6 摘要不符"
}
if (Test-Path -LiteralPath $decisionPath -PathType Leaf) {
    $decisionText = Get-Content -LiteralPath $decisionPath -Raw -Encoding UTF8
    Add-Check (
        $decisionText.Contains(
            "### 59. **决策 13：全部维度下 r.total = 0 的范围不纳入 R(T)**"
        )
    ) "Decision_log.md 缺少第 59 条决策 13"
}

$allowedChanges = @(
    "PhotoCleanupMVE.xcodeproj/project.pbxproj",
    "PhotoCleanupMVE/App/CleanupCoordinator.swift",
    "PhotoCleanupMVE/Services/PhotoLibraryService.swift",
    "PhotoCleanupMVETests/AlbumScopeWiringTests.swift",
    "Scripts/verify-IC-20260815-051.ps1",
    "selfcheck_IC-051_report.md"
)
$changedPaths = @(
    @(& git -C $projectRoot diff --name-only $taskBaseline)
    @(& git -C $projectRoot ls-files --others --exclude-standard)
) | Where-Object { $_ } | Sort-Object -Unique
foreach ($path in $changedPaths) {
    Add-Check ($allowedChanges -ccontains $path) "出现范围外改动：$path"
}

$forbiddenPatterns = @(
    '^SPEC-.*\.md$',
    '(^|/)Decision_log\.md$',
    '^PhotoCleanupMVE/Features/',
    '^PhotoCleanupMVE/Core/S[2345]StateMachine\.swift$',
    '^PhotoCleanupMVE/Localizable\.xcstrings$',
    '^\.github/workflows/'
)
foreach ($path in $changedPaths) {
    foreach ($pattern in $forbiddenPatterns) {
        Add-Check (-not ($path -match $pattern)) "禁止修改的路径发生变化：$path"
    }
}

$serviceText = Read-Text "PhotoCleanupMVE/Services/PhotoLibraryService.swift"
$coordinatorText = Read-Text "PhotoCleanupMVE/App/CleanupCoordinator.swift"
$s1Text = Read-Text "PhotoCleanupMVE/Core/S1StateMachine.swift"
$testText = Read-Text "PhotoCleanupMVETests/AlbumScopeWiringTests.swift"
$projectText = Read-Text "PhotoCleanupMVE.xcodeproj/project.pbxproj"

foreach ($fragment in @(
    "PHAssetCollection.fetchAssetCollections(",
    "s1Source.fetchAssetCollections(.album, .albumRegular)",
    "collection.collectionType == .album",
    "collection.collectionSubtype == .albumRegular",
    "!collection.isHidden",
    "!classifiedAssetIDs.contains(asset.identifier)",
    "case let .success(value) where value.isEmpty:",
    "return .success([])"
)) {
    Add-Check ($serviceText.Contains($fragment)) "S1 数据源缺少契约片段：$fragment"
}
Add-Check (
    $coordinatorText.Contains("photoLibrary.s1Ranges(groupedBy: groupingDimension)")
) "协调器未接入由服务提供的相册来源"
Add-Check (-not $coordinatorText.Contains("albumCollections: []")) "协调器仍向 S1 传入空相册来源"
Add-Check (
    $s1Text.Contains("groupingDimension == .month || groupingDimension == .year")
) "相册范围顺序保护条件缺失"
Add-Check (
    $s1Text.Contains("range.orderedAssetIDs(for: sortOrder)")
) "S1→S2 的 A 未按当前 O 形成"
Add-Check (
    [regex]::Matches(
        $projectText,
        [regex]::Escape("AlbumScopeWiringTests.swift")
    ).Count -eq 6
) "新增测试文件的工程引用数不是 6"

for ($index = 1; $index -le 7; $index += 1) {
    Add-Check (
        [regex]::Matches($testText, "func testIC051_T$index").Count -eq 1
    ) "T$index 专项测试数量不为 1"
}
Add-Check (-not $testText.Contains("XCTSkip")) "专项测试不得跳过"

$testFiles = Get-ChildItem -LiteralPath (
    Join-Path $projectRoot "PhotoCleanupMVETests"
) -Filter "*.swift" -File
$testCount = @(
    Select-String -LiteralPath $testFiles.FullName -Pattern '^\s*func\s+test'
).Count
Add-Check ($testCount -ge 280) "XCTest 静态总数不得少于 280，实际为 $testCount"

Add-Check (
    [regex]::Matches(
        $coordinatorText,
        'static\s+let\s+debugAssetLimit\s*=\s*300'
    ).Count -eq 1
) "debugAssetLimit 被改动"
Add-Check (
    -not [regex]::IsMatch(
        $serviceText + $coordinatorText,
        'URLSession|NWConnection|CFNetwork|https?://'
    )
) "本卡产品改动出现网络请求代码"

& (Join-Path $projectRoot "Scripts/selfcheck.ps1")
Add-Check ($LASTEXITCODE -eq 0) "通用 selfcheck.ps1 未通过"
& (Join-Path $projectRoot "Scripts/scan-hardcoded-user-visible-strings.ps1")
Add-Check ($LASTEXITCODE -eq 0) "用户可见硬编码扫描未通过"
& git -C $projectRoot diff --check $taskBaseline
Add-Check ($LASTEXITCODE -eq 0) "git diff --check 未通过"

$branchName = (& git -C $projectRoot branch --show-current).Trim()
Add-Check (
    $branchName -ceq "feature/ic-051-album-scope"
) "当前分支不是 feature/ic-051-album-scope"

$reportPath = Join-Path $projectRoot "selfcheck_IC-051_report.md"
if (-not $允许待回填CI) {
    Add-Check (Test-Path -LiteralPath $reportPath -PathType Leaf) "缺少最终自验报告"
    if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
        $reportText = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8
        foreach ($fragment in @(
            "测试总数：280",
            "completed / success",
            "https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/",
            "PhotoCleanupMVE-unsigned-",
            "未合并主干",
            "未执行 force push"
        )) {
            Add-Check ($reportText.Contains($fragment)) "最终报告缺少证据：$fragment"
        }
        for ($index = 1; $index -le 7; $index += 1) {
            Add-Check ($reportText.Contains("| T$index |")) "最终报告缺少 T$index 结果"
        }
    }
}

if (-not $允许未提交交付物) {
    $status = @(& git -C $projectRoot status --porcelain)
    Add-Check ($status.Count -eq 0) "完成态工作树不干净"
    $commitCount = [int](& git -C $projectRoot rev-list --count "$taskBaseline..HEAD")
    Add-Check ($commitCount -gt 0) "完成态没有本卡提交"
}

if ($script:failures.Count -gt 0) {
    Write-Host "IC-20260815-051 自验失败：共执行 $script:checkCount 项检查，失败 $($script:failures.Count) 项。" -ForegroundColor Red
    foreach ($failure in $script:failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "IC-20260815-051 自验通过：共执行 $script:checkCount 项检查，0 项失败；静态 XCTest 总数为 $testCount。" -ForegroundColor Green
