param(
    [switch]$允许未提交交付物,
    [switch]$允许待回填CI
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$taskBaseline = "2d1097e99ddc4b5c5aedca3281edf5d8664d0272"
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

function Normalize-Text {
    param([string]$Text)
    ($Text -replace "`r`n", "`n").TrimEnd("`n")
}

function Get-WorkingBlob {
    param([string]$RelativePath)
    (& git -C $projectRoot hash-object -- $RelativePath).Trim()
}

function Get-BaselineBlob {
    param([string]$RelativePath)
    (& git -C $projectRoot rev-parse "$taskBaseline`:$RelativePath").Trim()
}

$requiredFiles = @(
    "PhotoCleanupMVE/App/CleanupCoordinator.swift",
    "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift",
    "PhotoCleanupMVE/Core/S1StateMachine.swift",
    "PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift",
    "PhotoCleanupMVE/Features/S3/S3View.swift",
    "PhotoCleanupMVE/Localizable.xcstrings",
    "PhotoCleanupMVETests/FullFlowRoutingTests.swift",
    "Scripts/verify-IC-20260814-048.ps1",
    "Reports/IC-20260814-048-SELF-VERIFICATION.md"
)
foreach ($path in $requiredFiles) {
    Add-Check (Test-Path -LiteralPath (Join-Path $projectRoot $path) -PathType Leaf) "缺少交付文件：$path"
}

$specExpectations = @(
    @("SPEC-S1-20260814.v4.md", "9AAE723EBB565FD631C8E904EB1FC5598799AD9B132C4244C6198E64C0A1CB5D"),
    @("SPEC-S2-20260813.v13.md", "25741959F965B8D9438F7265745D70EE60339A6865E1763BDE71912782BED1D8"),
    @("SPEC-S3-S4-20260813.v7.md", "BED82109BE905466FEFF2A915D290E7FE98B5179801F6F475995CBED468AD786"),
    @("SPEC-S5-20260812.v5.md", "10CD2B7829126ABBD8FB66091B21169E698868CA67E345D0EABBA39D8D6221B7")
)
$specRoot = Split-Path -Parent $projectRoot
foreach ($expectation in $specExpectations) {
    $path = Join-Path $specRoot $expectation[0]
    Add-Check (Test-Path -LiteralPath $path -PathType Leaf) "缺少仓库外输入：$($expectation[0])"
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        Add-Check ($actualHash -ceq $expectation[1]) "SPEC 摘要不符：$($expectation[0])"
    }
}

$allowedChanges = @(
    "PhotoCleanupMVE.xcodeproj/project.pbxproj",
    "PhotoCleanupMVE/App/CleanupCoordinator.swift",
    "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift",
    "PhotoCleanupMVE/Core/S1StateMachine.swift",
    "PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift",
    "PhotoCleanupMVE/Features/S2/S2View.swift",
    "PhotoCleanupMVE/Features/S3/S3View.swift",
    "PhotoCleanupMVE/Localizable.xcstrings",
    "PhotoCleanupMVETests/FullFlowRoutingTests.swift",
    "Scripts/selfcheck.ps1",
    "Scripts/verify-IC-20260814-048.ps1",
    "Reports/IC-20260814-048-SELF-VERIFICATION.md"
)
$changedPaths = @(
    @(& git -C $projectRoot diff --name-only $taskBaseline)
    @(& git -C $projectRoot ls-files --others --exclude-standard)
) | Where-Object { $_ } | Sort-Object -Unique
foreach ($path in $changedPaths) {
    Add-Check ($allowedChanges -ccontains $path) "出现范围外改动：$path"
}
foreach ($path in $allowedChanges) {
    Add-Check ($changedPaths -ccontains $path) "缺少预期改动：$path"
}

$protectedPaths = @(
    "PhotoCleanupMVE/Core/SessionStore.swift",
    "PhotoCleanupMVE/Core/S2StateMachine.swift",
    "PhotoCleanupMVE/Core/S3StateMachine.swift",
    "PhotoCleanupMVE/Core/S4StateMachine.swift",
    "PhotoCleanupMVE/Core/S5StateMachine.swift",
    "PhotoCleanupMVETests/SessionStoreTests.swift",
    "PhotoCleanupMVETests/S1StateMachineTests.swift",
    "PhotoCleanupMVETests/S2StateMachineTests.swift",
    "PhotoCleanupMVETests/S3StateMachineTests.swift",
    "PhotoCleanupMVETests/S4StateMachineTests.swift",
    "PhotoCleanupMVETests/S5StateMachineTests.swift",
    ".github/workflows/ci.yml"
)
foreach ($path in $protectedPaths) {
    Add-Check ((Get-WorkingBlob $path) -ceq (Get-BaselineBlob $path)) "受保护文件发生变化：$path"
}

$s1Path = "PhotoCleanupMVE/Core/S1StateMachine.swift"
$baselineS1 = Normalize-Text ((& git -C $projectRoot show "$taskBaseline`:$s1Path") -join "`n")
$workingS1 = Normalize-Text (Read-Text $s1Path)
$routeMethodPattern = '(?s)\n    @discardableResult\n    func applyS2PendingDeletionChange.*?(?=\n    private static func areValid)'
$routeMethodMatches = [regex]::Matches($workingS1, $routeMethodPattern)
Add-Check ($routeMethodMatches.Count -eq 1) "S1 路由新增方法区块数量不符"
$s1WithoutRouteMethods = [regex]::Replace($workingS1, $routeMethodPattern, "")
Add-Check ($s1WithoutRouteMethods -ceq $baselineS1) "S1 除路由新增方法外出现语义改动"
Add-Check ($workingS1.Contains("func applyS2PendingDeletionChange")) "S1 缺少 S2 实时会话同步方法"
Add-Check ($workingS1.Contains("func applyS3Return")) "S1 缺少 S3 返回交集接收方法"

$coordinatorText = Read-Text "PhotoCleanupMVE/App/CleanupCoordinator.swift"
$appText = Read-Text "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"
$s3ViewText = Read-Text "PhotoCleanupMVE/Features/S3/S3View.swift"
$strategyText = Read-Text "PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift"
$s2ViewText = Read-Text "PhotoCleanupMVE/Features/S2/S2View.swift"
$testText = Read-Text "PhotoCleanupMVETests/FullFlowRoutingTests.swift"
$catalogText = Read-Text "PhotoCleanupMVE/Localizable.xcstrings"

foreach ($fragment in @(
    "case s1",
    "case s2",
    "func enterS1(sessionID:",
    "func enterS2(from handoff:",
    "func leaveS2(with payload:",
    "func enterConfirmationFromS2(with payload:",
    "func enterConfirmationFromS1",
    "func handleS3Return",
    "SessionStore(sessionID: nextSessionID)"
)) {
    Add-Check ($coordinatorText.Contains($fragment)) "协调器缺少接线片段：$fragment"
}
Add-Check ($appText.Contains("case .s1, .upstream, .finished:")) "S1 兼容落点未统一渲染"
Add-Check ($appText.Contains("case .s2:")) "应用未渲染 S2 路由"
Add-Check ($appText.Contains("S1View(")) "应用未接入 S1View"
Add-Check ($appText.Contains("S2View(")) "应用未接入 S2View"

Add-Check ($coordinatorText.Contains("s3Groups = submission.groups")) "S3 未接收分组划分"
Add-Check ($s3ViewText.Contains("coordinator.s3Groups")) "S3View 未按来源分组"
Add-Check ($s3ViewText.Contains('"s3.group.asset_count"')) "S3View 未显示组名与组内数量"
Add-Check ($catalogText.Contains('"s3.scope.source_summary.placeholder"')) "String Catalog 缺少当前范围说明占位"
Add-Check ($catalogText.Contains('"s3.group.asset_count"')) "String Catalog 缺少分组数量文案"

Add-Check ($strategyText.Contains("SPEC-S2 v13 未定项 8 的临时占位实现")) "图像策略未显式标注未定项 8 临时性质"
Add-Check ($strategyText.Contains("protocol S2PhotoImageRequesting")) "缺少可替换图像策略协议"
Add-Check ($strategyText.Contains("final class S2TemporaryPhotoKitImageStrategy")) "缺少 PhotoKit 临时策略对象"
Add-Check ($strategyText.Contains("options.isNetworkAccessAllowed = false")) "图像策略未明确禁止网络取图"
Add-Check ($strategyText.Contains("options.deliveryMode = .highQualityFormat")) "图像策略请求方式与报告约定不符"
Add-Check ($coordinatorText.Contains("degradedPreviewPolicy: .finalImageOnly")) "临时策略未锁定只显示最终图"
Add-Check (-not [regex]::IsMatch($s2ViewText, 'PHImageManager|PHImageRequestOptions|\.requestImage\(')) "S2View 出现直接 PhotoKit 图像请求"
Add-Check ($appText.Contains("strategy: s2PhotoImageStrategy")) "图像策略对象未从应用层注入"

$animationPattern = 'withAnimation|\.animation\s*\(|Animation\.|matchedGeometryEffect|\.transition\s*\(|contentTransition|PhaseAnimator|KeyframeAnimator'
$productSwiftFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot "PhotoCleanupMVE") -Recurse -Filter "*.swift"
$animationHits = Select-String -LiteralPath $productSwiftFiles.FullName -Pattern $animationPattern
Add-Check (-not [bool]$animationHits) "产品源码出现动画 API"

$networkPattern = 'URLSession|NWConnection|CFNetwork|https?://'
$newProductPaths = @(
    "PhotoCleanupMVE/App/CleanupCoordinator.swift",
    "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift",
    "PhotoCleanupMVE/Features/S2/S2TemporaryPhotoImageStrategy.swift",
    "PhotoCleanupMVE/Features/S3/S3View.swift"
)
$networkHits = Select-String -LiteralPath ($newProductPaths | ForEach-Object { Join-Path $projectRoot $_ }) -Pattern $networkPattern
Add-Check (-not [bool]$networkHits) "本卡产品改动出现网络请求代码"
Add-Check ([regex]::Matches($coordinatorText, 'static\s+let\s+debugAssetLimit\s*=\s*300').Count -eq 1) "debugAssetLimit 当前值不是 300"
Add-Check ([regex]::Matches($coordinatorText, 'limit:\s*Self\.debugAssetLimit').Count -eq 0) "debugAssetLimit 仍影响启动全流程"

$testFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot "PhotoCleanupMVETests") -Filter "*.swift"
$testCount = @(
    Select-String -LiteralPath $testFiles.FullName -Pattern '^\s*func\s+test'
).Count
Add-Check ($testCount -eq 273) "XCTest 静态总数应为 273，实际为 $testCount"
for ($index = 1; $index -le 6; $index += 1) {
    $number = $index.ToString("000")
    Add-Check ([regex]::Matches($testText, "func testIC048_$number").Count -eq 1) "IC048-$number 专项测试数量不为 1"
}
Add-Check (-not $testText.Contains("XCTSkip")) "专项测试不得跳过"

$projectText = Read-Text "PhotoCleanupMVE.xcodeproj/project.pbxproj"
foreach ($name in @(
    "S2TemporaryPhotoImageStrategy.swift",
    "FullFlowRoutingTests.swift"
)) {
    Add-Check ([regex]::Matches($projectText, [regex]::Escape($name)).Count -eq 6) "工程对 $name 的引用数不是 6"
}

& (Join-Path $projectRoot "Scripts/selfcheck.ps1")
Add-Check ($LASTEXITCODE -eq 0) "通用 selfcheck.ps1 未通过"
& (Join-Path $projectRoot "Scripts/scan-hardcoded-user-visible-strings.ps1")
Add-Check ($LASTEXITCODE -eq 0) "用户可见硬编码扫描未通过"

& git -C $projectRoot diff --check
Add-Check ($LASTEXITCODE -eq 0) "git diff --check 未通过"

$untracked = @(& git -C $projectRoot ls-files --others --exclude-standard)
if (-not $允许未提交交付物) {
    Add-Check ($untracked.Count -eq 0) "完成态存在未跟踪条目"
    $status = @(& git -C $projectRoot status --porcelain)
    Add-Check ($status.Count -eq 0) "完成态工作树不干净"
}

$reportPath = Join-Path $projectRoot "Reports/IC-20260814-048-SELF-VERIFICATION.md"
if ((Test-Path -LiteralPath $reportPath -PathType Leaf) -and -not $允许待回填CI) {
    $reportText = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8
    foreach ($evidence in @(
        'CI 终态：`completed / success`',
        '全量 XCTest：273 项，0 失败、0 unexpected',
        'Release 构建：成功',
        '未签名 IPA：产出成功'
    )) {
        Add-Check ($reportText.Contains($evidence)) "报告缺少最终 CI 证据：$evidence"
    }
}

if ($script:failures.Count -gt 0) {
    Write-Host "IC-20260814-048 自验失败：共执行 $script:checkCount 项检查，失败 $($script:failures.Count) 项。" -ForegroundColor Red
    foreach ($failure in $script:failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "IC-20260814-048 自验通过：共执行 $script:checkCount 项检查，0 项失败。" -ForegroundColor Green
