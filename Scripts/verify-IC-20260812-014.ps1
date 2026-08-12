param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$projectRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $projectRoot "PhotoCleanupMVETests"
$matrixPath = Join-Path $projectRoot "Reports/TRACEABILITY-S3-S5.md"
$projectPath = Join-Path $projectRoot "PhotoCleanupMVE.xcodeproj/project.pbxproj"
$baseline = "cb19f63b4338f8d004337926d8cf71f6ddbacbe3"
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

Write-Host "运行既有结构门禁……"
& (Join-Path $PSScriptRoot "verify-IC-20260812-010.ps1")
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$expectedClauses = @(
    "C34-114", "C34-116", "C34-128", "C34-130", "C34-146",
    "C34-152", "C34-153", "C34-157", "C34-163", "C34-165",
    "C34-166", "C34-186", "C34-209", "C34-210", "C34-211",
    "C5-006", "C5-031", "C5-034", "C5-039", "C5-069", "C5-086",
    "C5-087", "C5-101", "C5-143", "C5-144", "C5-145"
)
Assert-Check ($expectedClauses.Count -eq 26) "题卡条款总数应为 26，实际为 $($expectedClauses.Count)"
Assert-Check (($expectedClauses | Sort-Object -Unique).Count -eq 26) "题卡条款编号存在重复"
Assert-Check (@($expectedClauses | Where-Object { $_.StartsWith("C34-") }).Count -eq 15) "C34 条款应为 15 条"
Assert-Check (@($expectedClauses | Where-Object { $_.StartsWith("C5-") }).Count -eq 11) "C5 条款应为 11 条"

$coverageTestPath = Join-Path $testRoot "CoverageGapTests.swift"
$coverageTestText = Get-Content -LiteralPath $coverageTestPath -Raw -Encoding UTF8
$coverageMethodMatches = [regex]::Matches(
    $coverageTestText,
    "(?m)^\s*func\s+test(C(?:34|5)_\d{3})[A-Za-z0-9_]*\s*\("
)
$coveredClauses = @(
    $coverageMethodMatches |
        ForEach-Object { $_.Groups[1].Value.Replace("_", "-") }
)
Assert-Check ($coveredClauses.Count -eq 26) "B 组新增测试方法应为 26 个，实际为 $($coveredClauses.Count)"
Assert-Check (($coveredClauses | Sort-Object -Unique).Count -eq 26) "B 组新增测试方法的条款编号存在重复"
foreach ($clause in $expectedClauses) {
    Assert-Check ($coveredClauses -ccontains $clause) "B 组缺少条款测试方法：$clause"
}
foreach ($clause in $coveredClauses) {
    Assert-Check ($expectedClauses -ccontains $clause) "B 组出现范围外条款测试方法：$clause"
}

$matrixLines = @(Get-Content -LiteralPath $matrixPath -Encoding UTF8)
$transitionCells = [System.Collections.Generic.List[object]]::new()
foreach ($line in $matrixLines) {
    $fields = @($line -split "`t", 7)
    if ($fields.Count -ne 7) {
        continue
    }
    if ($fields[6] -cmatch '^(可达单元格|断言型条款)（事件“(.+)” × 起始状态“([^”]+)”）') {
        $transitionCells.Add([pscustomobject]@{
            ClauseID = $fields[0]
            Specification = $fields[1]
            Kind = $Matches[1]
            Event = $Matches[2]
            SourceState = $Matches[3]
        })
    }
}
Assert-Check ($transitionCells.Count -eq 115) "矩阵迁移单元格应为 115 个，实际为 $($transitionCells.Count)"
Assert-Check (@($transitionCells | Where-Object { $_.Kind -ceq "断言型条款" }).Count -eq 63) "矩阵不可达单元格应为 63 个"
Assert-Check (@($transitionCells | Where-Object { $_.Kind -ceq "可达单元格" }).Count -eq 52) "矩阵可达单元格应为 52 个"
$coordinates = @(
    $transitionCells |
        ForEach-Object { "$($_.Specification)|$($_.Event)|$($_.SourceState)" }
)
Assert-Check (($coordinates | Sort-Object -Unique).Count -eq 115) "矩阵迁移单元格坐标存在重复"
Assert-Check (($transitionCells.ClauseID | Sort-Object -Unique).Count -eq 115) "矩阵迁移单元格条款编号存在重复"

$guardPath = Join-Path $testRoot "TransitionTableGuardTests.swift"
$guardText = Get-Content -LiteralPath $guardPath -Raw -Encoding UTF8
Assert-Check ($guardText.Contains("loadTransitionCells()")) "A 组守卫未在运行时加载迁移矩阵"
Assert-Check ($guardText.Contains("for cell in cells")) "A 组守卫未遍历解析出的迁移单元格"
Assert-Check ($guardText.Contains("Bundle(for: Self.self).url")) "A 组守卫未从测试资源读取追溯文件"
Assert-Check (-not ($guardText -cmatch 'TransitionCell\s*\(\s*clauseID:\s*"C(?:34|5)-')) "A 组守卫手工重录了迁移条款"

$testFiles = @(Get-ChildItem -LiteralPath $testRoot -Filter "*.swift" -File)
$testMethods = @(
    Select-String -LiteralPath $testFiles.FullName -Pattern '^\s*func\s+test[A-Za-z0-9_]+\s*\('
)
Assert-Check ($testMethods.Count -eq 176) "XCTest 静态总数应为 176，实际为 $($testMethods.Count)"

$projectText = Get-Content -LiteralPath $projectPath -Raw -Encoding UTF8
Assert-Check ($projectText.Contains("TransitionTableGuardTests.swift")) "工程未引用 A 组测试源码"
Assert-Check ($projectText.Contains("CoverageGapTests.swift")) "工程未引用 B 组测试源码"
Assert-Check ($projectText.Contains("TRACEABILITY-S3-S5.md（测试资源）")) "工程未将追溯文件加入测试资源"

$uiTestTargetCount = [regex]::Matches(
    $projectText,
    'productType\s*=\s*"com\.apple\.product-type\.bundle\.ui-testing"'
).Count
Assert-Check ($uiTestTargetCount -eq 0) "全仓库不得存在 XCUITest target"
$uiTestSymbols = @(
    Select-String -LiteralPath $testFiles.FullName -Pattern '\b(XCUIApplication|XCUIDevice|XCUICoordinate)\b'
)
Assert-Check ($uiTestSymbols.Count -eq 0) "单元测试源码不得使用 XCUITest API"

Push-Location $projectRoot
try {
    $baselineExists = (& git cat-file -t $baseline 2>$null) -eq "commit"
    Assert-Check $baselineExists "Git 中不存在产品基线：$baseline"
    if ($baselineExists) {
        $baselineProduct = @{}
        foreach ($line in @(& git ls-tree -r $baseline -- PhotoCleanupMVE)) {
            if ($line -cmatch '^\d+\s+blob\s+([0-9a-f]{40})\t(.+)$') {
                $baselineProduct[$Matches[2]] = $Matches[1]
            }
        }
        $currentProduct = @{}
        $projectRootPrefix = $projectRoot.TrimEnd('\') + '\'
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot "PhotoCleanupMVE") -File -Recurse) {
            $relativePath = $file.FullName.Substring($projectRootPrefix.Length).Replace('\', '/')
            $currentProduct[$relativePath] = $file.FullName
        }
        Assert-Check ($currentProduct.Count -eq $baselineProduct.Count) "产品源码文件集合相对基线发生变化"
        foreach ($relativePath in $baselineProduct.Keys) {
            Assert-Check ($currentProduct.ContainsKey($relativePath)) "产品文件相对基线缺失：$relativePath"
            if ($currentProduct.ContainsKey($relativePath)) {
                $actualObject = (& git hash-object "--path=$relativePath" -- $relativePath).Trim()
                Assert-Check ($actualObject -ceq $baselineProduct[$relativePath]) "产品 Git blob 相对基线变化：$relativePath"
            }
        }
        foreach ($relativePath in $currentProduct.Keys) {
            Assert-Check ($baselineProduct.ContainsKey($relativePath)) "产品目录新增文件：$relativePath"
        }
    }
}
finally {
    Pop-Location
}

if ($failures.Count -gt 0) {
    Write-Host "IC-20260812-014 自验失败：共执行 $checkCount 项检查，失败 $($failures.Count) 项。" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "IC-20260812-014 自验通过：共执行 $checkCount 项检查。" -ForegroundColor Green
Write-Host "统计：迁移单元格 115（不可达 63、可达 52）；B 组 26/26；新增测试 27；XCTest 总数 176；产品 blob 变化 0；XCUITest target 0。"
