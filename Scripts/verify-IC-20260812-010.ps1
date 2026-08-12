param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message)
}

Write-Host "运行通用结构与硬编码自验……"
& (Join-Path $PSScriptRoot "selfcheck.ps1")
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$sourceRoot = Join-Path $projectRoot "PhotoCleanupMVE"
$testRoot = Join-Path $projectRoot "PhotoCleanupMVETests"
$catalogPath = Join-Path $sourceRoot "Localizable.xcstrings"
$productSwiftFiles = @(
    Get-ChildItem -LiteralPath $sourceRoot -Filter "*.swift" -File -Recurse
)
$testSwiftFiles = @(
    Get-ChildItem -LiteralPath $testRoot -Filter "*.swift" -File
)

$legacyS3Patterns = @(
    ("submission" + "Limit")
    ("over" + "Limit")
    ("S3-" + "3")
    "单次最多提交\s+[0-9]+\s*张"
    "资产数量必须位于\s*1\s*至\s*[0-9]+"
    "\(\s*1\s*\.\.\.\s*[0-9]+\s*\)\.contains\(\s*(?:assetIDs\.count|assetCount)"
)
foreach ($pattern in $legacyS3Patterns) {
    $hits = @(Select-String -LiteralPath $productSwiftFiles.FullName -Pattern $pattern)
    if ($hits.Count -gt 0) {
        Add-Failure "产品源码仍有旧 S3 数量上限实现：$($hits[0].Path):$($hits[0].LineNumber)"
    }
}

$s3TestPath = Join-Path $testRoot "S3StateMachineTests.swift"
$s3TestText = Get-Content -LiteralPath $s3TestPath -Raw -Encoding UTF8
$removedCellPattern = "testCell(?:" + "06" + "|" + "10" + ")"
if ($s3TestText -match $removedCellPattern) {
    Add-Failure "S3 已作废单元格的测试仍有残留"
}
$removedStateToken = "S3_" + "3"
if ($s3TestText.Contains($removedStateToken)) {
    Add-Failure "S3 已删除状态的测试仍有残留"
}

try {
    $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 |
        ConvertFrom-Json
}
catch {
    Add-Failure "String Catalog 无法解析：$($_.Exception.Message)"
    $catalog = $null
}

if ($null -ne $catalog) {
    $removedKeys = @(
        ("s3.submission." + "limit_notice")
        ("s3.submission." + "over_limit_notice")
        ("s3.state." + "over_limit")
        ("s3.volume." + "over_limit")
    )
    foreach ($key in $removedKeys) {
        if ($catalog.strings.PSObject.Properties.Name -contains $key) {
            Add-Failure "String Catalog 仍包含已删除条目"
        }
    }

    $expectedNewStrings = [ordered]@{
        "s5.section.deletion_cancelled" = "已取消删除"
        "s5.status.assets_intact" = "照片都还在"
        "s5.summary.cancelled_result" = "本次提交 {count} 张，全部未处理"
    }
    foreach ($entry in $expectedNewStrings.GetEnumerator()) {
        $property = $catalog.strings.PSObject.Properties[$entry.Key]
        if ($null -eq $property) {
            Add-Failure "String Catalog 缺少新增条目：$($entry.Key)"
            continue
        }
        $languages = @($property.Value.localizations.PSObject.Properties.Name)
        if ($languages.Count -ne 1 -or $languages[0] -ne "zh-Hans") {
            Add-Failure "新增条目语言集合不只包含 zh-Hans：$($entry.Key)"
        }
        $actualValue = $property.Value.localizations."zh-Hans".stringUnit.value
        if ($actualValue -ne $entry.Value) {
            Add-Failure "新增条目文案不匹配：$($entry.Key)"
        }
    }
}

$s4Path = Join-Path $sourceRoot "Core/S4StateMachine.swift"
$s4Text = Get-Content -LiteralPath $s4Path -Raw -Encoding UTF8
$requiredS4Fragments = @(
    "systemDomain == PHPhotosErrorDomain",
    "systemCode == 3072",
    'case movedToRecentlyDeleted = "S5-T0"',
    'case failed = "S5-F"',
    'case cancelled = "S5-C"',
    'case unknown = "S5-U"',
    "proposal.downstreamTargetState = .movedToRecentlyDeleted",
    "proposal.downstreamTargetState = .unknown"
)
foreach ($fragment in $requiredS4Fragments) {
    if (-not $s4Text.Contains($fragment)) {
        Add-Failure "S4 交接或取消判定缺少实现片段：$fragment"
    }
}

$s5Files = @(
    (Join-Path $sourceRoot "Core/S5StateMachine.swift")
    (Join-Path $sourceRoot "Features/S5/S5View.swift")
)
$forbiddenS5Patterns = @(
    "PHPhotosErrorDomain",
    "3072",
    "\.systemDomain\b",
    "\.systemCode\b",
    "NSError",
    "error\s*\.\s*code",
    "reason\s*\.\s*category"
)
foreach ($pattern in $forbiddenS5Patterns) {
    $hits = @(Select-String -LiteralPath $s5Files -Pattern $pattern)
    if ($hits.Count -gt 0) {
        Add-Failure "S5 出现错误码二次判定或解析：$($hits[0].Path):$($hits[0].LineNumber)"
    }
}

$s5MachinePath = Join-Path $sourceRoot "Core/S5StateMachine.swift"
$s5MachineText = Get-Content -LiteralPath $s5MachinePath -Raw -Encoding UTF8
$readCalls = [regex]::Matches($s5MachineText, "readFreeDiskStrictGB\(\)").Count
if ($readCalls -ne 2) {
    Add-Failure "磁盘读取触发点应恰为两个，实际为 $readCalls 个"
}
if ($s5MachineText -match "(?i)\b(?:while|Timer|Task\.sleep)\b") {
    Add-Failure "S5 状态机出现轮询或定时读取实现"
}
if (-not ($s5MachineText -match "blockedByUndecidedThreshold\s*=\s*true")) {
    Add-Failure "缺少 L3 展示分支规格阻断标记"
}
$thresholdNumericHits = @(
    Select-String -LiteralPath $productSwiftFiles.FullName -Pattern "(?i)(?:l3DisplayThreshold|L3显示门槛)\s*(?:=|:)\s*[-+]?[0-9]"
)
if ($thresholdNumericHits.Count -gt 0) {
    Add-Failure "L3 显示门槛存在数值实现"
}

$s5ViewPath = Join-Path $sourceRoot "Features/S5/S5View.swift"
$s5ViewText = Get-Content -LiteralPath $s5ViewPath -Raw -Encoding UTF8
$requiredS5ViewFragments = @(
    'L10n.text("s5.section.deletion_cancelled")',
    'L10n.text("s5.status.assets_intact")',
    '"s5.summary.cancelled_result"',
    'coordinator.confirmRecentlyDeletedCleared()'
)
foreach ($fragment in $requiredS5ViewFragments) {
    if (-not $s5ViewText.Contains($fragment)) {
        Add-Failure "S5 页面缺少实现片段：$fragment"
    }
}
if ($s5ViewText -match 'confirm_recently_deleted_cleared"\)\s*\{\s*\}\s*\.disabled\(true\)') {
    Add-Failure "最近删除确认按钮仍被固定禁用"
}

$s5TestPath = Join-Path $testRoot "S5StateMachineTests.swift"
$s5TestText = Get-Content -LiteralPath $s5TestPath -Raw -Encoding UTF8
$requiredS5CancellationTests = @(
    "testCancellationDoesNotReadFreeDiskStrictGB",
    "testCancellationDoesNotShowL3",
    "testCancellationDoesNotShowSystemErrorDomainOrCode",
    "testCancellationDoesNotShowRecentlyDeletedConfirmationAction",
    "testCancellationVisibleCopyAvoidsFailureAndIncompleteWording"
)
foreach ($testName in $requiredS5CancellationTests) {
    if (-not $s5TestText.Contains($testName)) {
        Add-Failure "S5-C 禁用项缺少独立测试断言：$testName"
    }
}

$testCases = @(Select-String -LiteralPath $testSwiftFiles.FullName -Pattern "^\s*func\s+test")
if ($testCases.Count -ne 176) {
    Add-Failure "XCTest 静态计数应为 176，实际为 $($testCases.Count)"
}

$workspaceRoot = Split-Path -Parent $projectRoot
$specChecks = [ordered]@{
    "SPEC-S3-S4-20260812.v6.md" = "BF52BBE87692A253BDA9C2AC8B55712C76AB453E3AAF6C5D286BC15835E04C7D"
    "SPEC-S5-20260812.v5.md" = "10CD2B7829126ABBD8FB66091B21169E698868CA67E345D0EABBA39D8D6221B7"
}
foreach ($entry in $specChecks.GetEnumerator()) {
    $path = Join-Path $workspaceRoot $entry.Key
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($actualHash -ne $entry.Value) {
            Add-Failure "规格文件摘要不匹配：$($entry.Key)"
        }
    }
    else {
        Write-Host "  - CI 仓库外规格未随检出提供，跳过摘要复核：$($entry.Key)"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "专项自验失败，共 $($failures.Count) 项：" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "专项自验通过：S3 三状态、S4 四值交接、S5-C、L3 两次单读、按钮启用及 176 项测试静态覆盖均符合本卡要求。" -ForegroundColor Green
