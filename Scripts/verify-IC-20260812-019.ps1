param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot "PhotoCleanupMVE"
$testRoot = Join-Path $projectRoot "PhotoCleanupMVETests"
$baseline = "3f7a206bdfb463aabd034b9bdbc1cf666b428a11"
$failures = [System.Collections.Generic.List[string]]::new()
$checkCount = 0

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

function Assert-Check {
    param([bool]$Condition, [string]$FailureMessage)
    $script:checkCount++
    if (-not $Condition) {
        Add-Failure $FailureMessage
    }
}

function Normalize-Text {
    param([string]$Text)
    return $Text.Replace("`r`n", "`n").TrimEnd()
}

function Get-ServiceImplementation {
    param([string]$Text)
    $normalized = Normalize-Text $Text
    $start = $normalized.IndexOf(
        "struct PhotoDeletionService",
        [System.StringComparison]::Ordinal
    )
    if ($start -lt 0) {
        return ""
    }
    return $normalized.Substring($start).Replace(
        "struct PhotoDeletionService: PhotoDeletionServicing",
        "struct PhotoDeletionService"
    )
}

Write-Host "运行通用结构门禁……"
& (Join-Path $PSScriptRoot "selfcheck.ps1")
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$servicePath = Join-Path $sourceRoot "Services/PhotoDeletionService.swift"
$coordinatorPath = Join-Path $sourceRoot "App/CleanupCoordinator.swift"
$s4Path = Join-Path $sourceRoot "Core/S4StateMachine.swift"
$testPath = Join-Path $testRoot "S4StateMachineTests.swift"
$workflowPath = Join-Path $projectRoot ".github/workflows/ci.yml"
$reportPath = Join-Path $projectRoot "Reports/IC-20260812-019-SELF-VERIFICATION.md"
$traceabilityPath = Join-Path $projectRoot "Reports/TRACEABILITY-S3-S5.md"

foreach ($path in @(
    $servicePath,
    $coordinatorPath,
    $s4Path,
    $testPath,
    $workflowPath,
    $reportPath,
    $traceabilityPath
)) {
    Assert-Check (Test-Path -LiteralPath $path -PathType Leaf) "缺少专项自验输入：$path"
}

$serviceText = Get-Content -LiteralPath $servicePath -Raw -Encoding UTF8
$coordinatorText = Get-Content -LiteralPath $coordinatorPath -Raw -Encoding UTF8
$s4Text = Get-Content -LiteralPath $s4Path -Raw -Encoding UTF8
$testText = Get-Content -LiteralPath $testPath -Raw -Encoding UTF8
$workflowText = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8

Assert-Check ($serviceText.Contains("protocol PhotoDeletionServicing: Sendable")) "缺少 PhotoDeletionServicing 协议"
Assert-Check ($serviceText.Contains("struct PhotoDeletionService: PhotoDeletionServicing")) "PhotoDeletionService 未遵循协议"
$protocolEnd = $serviceText.IndexOf("enum DeletionServiceDependency", [System.StringComparison]::Ordinal)
Assert-Check ($protocolEnd -gt 0) "缺少生产删除服务默认依赖工厂"
if ($protocolEnd -gt 0) {
    $protocolText = $serviceText.Substring(0, $protocolEnd)
    Assert-Check ([regex]::Matches($protocolText, "func\s+startDeletion\s*\(").Count -eq 1) "协议未且仅未声明一次 startDeletion"
    Assert-Check ([regex]::Matches($protocolText, "func\s+systemFailureCallback\s*\(").Count -eq 1) "协议未且仅未声明一次 systemFailureCallback"
}
Assert-Check ($serviceText.Contains("PhotoDeletionService()")) "生产默认依赖不再构造 PhotoDeletionService"

Push-Location $projectRoot
try {
    $baselineType = (& git cat-file -t $baseline 2>$null)
    Assert-Check ($baselineType -eq "commit") "Git 中不存在专项产品基线：$baseline"
    if ($baselineType -eq "commit") {
        $baselineServiceText = @(& git show "${baseline}:PhotoCleanupMVE/Services/PhotoDeletionService.swift") -join "`n"
        Assert-Check ($LASTEXITCODE -eq 0) "无法读取基线 PhotoDeletionService.swift"
        if ($LASTEXITCODE -eq 0) {
            $currentImplementation = Get-ServiceImplementation $serviceText
            $baselineImplementation = Get-ServiceImplementation $baselineServiceText
            Assert-Check (
                [string]::Equals(
                    $currentImplementation,
                    $baselineImplementation,
                    [System.StringComparison]::Ordinal
                )
            ) "PhotoDeletionService 原方法签名或实现体发生变化"
        }
    }

    $allowedChanges = @(
        ".github/workflows/ci.yml",
        "PhotoCleanupMVE/App/CleanupCoordinator.swift",
        "PhotoCleanupMVE/Core/S4StateMachine.swift",
        "PhotoCleanupMVE/Services/PhotoDeletionService.swift",
        "PhotoCleanupMVETests/S4StateMachineTests.swift",
        "Reports/IC-20260812-019-SELF-VERIFICATION.md",
        "Scripts/selfcheck.ps1",
        "Scripts/verify-IC-20260812-019.ps1"
    )
    $changedPaths = @(
        @(& git diff --name-only $baseline --) +
        @(& git ls-files --others --exclude-standard) |
            Where-Object { $_ } |
            Sort-Object -Unique
    )
    foreach ($changedPath in $changedPaths) {
        Assert-Check ($allowedChanges -ccontains $changedPath) "出现范围外改动：$changedPath"
    }
    foreach ($requiredChange in $allowedChanges[0..4]) {
        Assert-Check ($changedPaths -ccontains $requiredChange) "缺少预期实现改动：$requiredChange"
    }
}
finally {
    Pop-Location
}

Assert-Check (-not ($coordinatorText -cmatch '\bPhotoDeletionService\b')) "CleanupCoordinator 仍直接引用具体删除服务"
Assert-Check (-not ($s4Text -cmatch '\bPhotoDeletionService\b')) "S4StateMachine 仍直接引用具体删除服务"
Assert-Check ($coordinatorText.Contains("private let deletionService: any PhotoDeletionServicing")) "协调器未依赖删除服务协议"
Assert-Check ($coordinatorText.Contains("DeletionServiceDependency.production()")) "协调器未保留生产默认注入"
Assert-Check ($s4Text.Contains("private let deletionService: (any PhotoDeletionServicing)?")) "S4 状态机未依赖删除服务协议"
Assert-Check ($s4Text.Contains("from submissionSource: S3StateMachine")) "S4 缺少从 S3 冻结来源启动的入口"
Assert-Check ($s4Text.Contains("submissionSource.freezeSubmissionSnapshot()")) "S4 启动入口未冻结 S3 快照"
Assert-Check ($s4Text.Contains("guard let deletionService else")) "S4 删除入口未阻断无冻结来源的实例"

$startIndex = $coordinatorText.IndexOf("from: machine", [System.StringComparison]::Ordinal)
$assignIndex = $coordinatorText.IndexOf("s4Machine = next", [System.StringComparison]::Ordinal)
$deleteIndex = $coordinatorText.IndexOf("next.startDeletion", [System.StringComparison]::Ordinal)
$routeIndex = $coordinatorText.IndexOf("route = .execution", [System.StringComparison]::Ordinal)
Assert-Check (
    $startIndex -ge 0 -and
    $assignIndex -gt $startIndex -and
    $deleteIndex -gt $assignIndex -and
    $routeIndex -gt $deleteIndex
) "协调器生产顺序不是冻结并持久化、写入 S4、调用删除、进入执行页"

Assert-Check ($testText.Contains("private final class SpyDeletionService")) "缺少 SpyDeletionService"
foreach ($fragment in @(
    "private(set) var callOrder",
    "private(set) var receivedSnapshots",
    "var callCount: Int",
    "var startDeletionCallCount: Int"
)) {
    Assert-Check ($testText.Contains($fragment)) "删除服务测试替身缺少记录字段：$fragment"
}

$expectedTests = @(
    "testC34_020DeletionStartsOnlyAfterSnapshotFreeze",
    "testC34_047UnfrozenSnapshotCannotReachDeletionService",
    "testC34_104FreezeFailureDoesNotCallDeletionService"
)
foreach ($testName in $expectedTests) {
    Assert-Check ([regex]::Matches($testText, "func\s+$testName\s*\(").Count -eq 1) "缺少或重复专项测试：$testName"
}
Assert-Check ($testText.Contains("XCTAssertEqual(deletionService.startDeletionCallCount, 1)")) "C34-020 未断言删除调用次数"
Assert-Check ([regex]::Matches($testText, "XCTAssertEqual\(deletionService\.startDeletionCallCount, 0\)").Count -eq 1) "C34-104 未且仅未断言一次零调用"
Assert-Check ($testText.Contains("XCTAssertEqual(deletionService.callCount, 0)")) "C34-047 未断言删除替身零调用"
Assert-Check ($testText.Contains("frozenSnapshotObservedAtCall")) "C34-020 未记录删除调用时的冻结快照"

$testFiles = @(Get-ChildItem -LiteralPath $testRoot -Filter "*.swift" -File)
$testMethods = @(
    Select-String -LiteralPath $testFiles.FullName -Pattern '^\s*func\s+test[A-Za-z0-9_]+\s*\('
)
Assert-Check ($testMethods.Count -eq 179) "XCTest 静态总数应为 179，实际为 $($testMethods.Count)"

$traceabilityHash = (Get-FileHash -LiteralPath $traceabilityPath -Algorithm SHA256).Hash
Assert-Check ($traceabilityHash -ceq "54B409B912A259CBE0028F35E70001CF2263A6A9E2799A1E75F34124055E7C50") "TRACEABILITY-S3-S5.md 发生变化"
Assert-Check ($workflowText.Contains("run: ./Scripts/verify-IC-20260812-019.ps1")) "CI 未运行本卡专项自验"

$projectText = Get-Content -LiteralPath (Join-Path $projectRoot "PhotoCleanupMVE.xcodeproj/project.pbxproj") -Raw -Encoding UTF8
$uiTestTargetCount = [regex]::Matches(
    $projectText,
    'productType\s*=\s*"com\.apple\.product-type\.bundle\.ui-testing"'
).Count
Assert-Check ($uiTestTargetCount -eq 0) "全仓库不得存在 XCUITest target"

if ($failures.Count -gt 0) {
    Write-Host "IC-20260812-019 自验失败：共执行 $checkCount 项检查，失败 $($failures.Count) 项。" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "IC-20260812-019 自验通过：共执行 $checkCount 项检查。" -ForegroundColor Green
Write-Host "统计：新增专项测试 3；XCTest 总数 179；删除服务协议方法 2；XCUITest target 0；阻塞 0。"
