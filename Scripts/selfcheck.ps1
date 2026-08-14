param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message)
}

$baselineProductSourceFiles = @(
    "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift",
    "PhotoCleanupMVE/App/CleanupCoordinator.swift",
    "PhotoCleanupMVE/Core/L10n.swift",
    "PhotoCleanupMVE/Core/AssetModels.swift",
    "PhotoCleanupMVE/Core/S3StateMachine.swift",
    "PhotoCleanupMVE/Core/S4StateMachine.swift",
    "PhotoCleanupMVE/Core/S5StateMachine.swift",
    "PhotoCleanupMVE/Core/SessionPersistence.swift",
    "PhotoCleanupMVE/Services/PhotoLibraryService.swift",
    "PhotoCleanupMVE/Services/AssetSizeScanner.swift",
    "PhotoCleanupMVE/Services/PhotoDeletionService.swift",
    "PhotoCleanupMVE/Services/FreeDiskSpaceReader.swift",
    "PhotoCleanupMVE/Features/S3/S3View.swift",
    "PhotoCleanupMVE/Features/S4/S4View.swift",
    "PhotoCleanupMVE/Features/S5/S5View.swift",
    "PhotoCleanupMVE/Features/Shared/ThumbnailView.swift"
)

$requiredFiles = @(
    ".gitattributes",
    "PhotoCleanupMVE.xcodeproj/project.pbxproj",
    "PhotoCleanupMVE.xcodeproj/xcshareddata/xcschemes/PhotoCleanupMVE.xcscheme",
    "PhotoCleanupMVE/Info.plist",
    "PhotoCleanupMVE/Assets.xcassets/Contents.json",
    "PhotoCleanupMVE/Assets.xcassets/RECENTLY_DELETED_PLACEHOLDER.imageset/Contents.json",
    "PhotoCleanupMVE/Assets.xcassets/RECENTLY_DELETED_PLACEHOLDER.imageset/RECENTLY_DELETED_PLACEHOLDER.png",
    "PhotoCleanupMVE/Localizable.xcstrings",
    "PhotoCleanupMVETests/S3StateMachineTests.swift",
    "PhotoCleanupMVETests/SnapshotInvariantTests.swift",
    "PhotoCleanupMVETests/VolumeFormattingTests.swift",
    "PhotoCleanupMVETests/S4StateMachineTests.swift",
    "PhotoCleanupMVETests/S5StateMachineTests.swift",
    "PhotoCleanupMVETests/CollectionInvariantTests.swift",
    "PhotoCleanupMVETests/TransitionTableGuardTests.swift",
    "PhotoCleanupMVETests/CoverageGapTests.swift",
    "Scripts/test-xcode.sh",
    "Scripts/scan-hardcoded-user-visible-strings.ps1",
    "Scripts/verify-IC-20260812-010.ps1",
    "Reports/IC-20260812-010-SELF-VERIFICATION.md",
    "Reports/IC-20260811-002-SELF-VERIFICATION.md",
    "Reports/SELF-VERIFICATION.md",
    "Reports/CHANGE-LOG-007R.md",
    "Reports/UNDECIDED-ITEMS.md",
    "Reports/PROJECT-TREE.md",
    ".github/workflows/ci.yml",
    "README.md"
)

foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        Add-Failure "缺少交付文件：$relativePath"
    }
}

$projectFile = Join-Path $projectRoot "PhotoCleanupMVE.xcodeproj/project.pbxproj"
if (Test-Path -LiteralPath $projectFile -PathType Leaf) {
    $projectText = Get-Content -LiteralPath $projectFile -Raw -Encoding UTF8
    $requiredProjectValues = @(
        "PRODUCT_BUNDLE_IDENTIFIER = com.iphonephotomanagement.PhotoCleanupMVE;",
        "PRODUCT_BUNDLE_IDENTIFIER = com.iphonephotomanagement.PhotoCleanupMVETests;",
        "IPHONEOS_DEPLOYMENT_TARGET = 17.0;",
        "SWIFT_VERSION = 5.0;"
    )
    foreach ($value in $requiredProjectValues) {
        if (-not $projectText.Contains($value)) {
            Add-Failure "工程配置缺少：$value"
        }
    }

    $productTypes = @(
        [regex]::Matches($projectText, 'productType = "([^"]+)";') |
            ForEach-Object { $_.Groups[1].Value }
    )
    $requiredProductTypes = @(
        "com.apple.product-type.application",
        "com.apple.product-type.bundle.unit-test"
    )
    if ($productTypes.Count -ne $requiredProductTypes.Count) {
        Add-Failure "工程 target 数量应为 2，实际为 $($productTypes.Count)"
    }
    foreach ($productType in $requiredProductTypes) {
        if ($productTypes -cnotcontains $productType) {
            Add-Failure "工程缺少 target 类型：$productType"
        }
    }
    if ($projectText.Contains("com.apple.product-type.bundle.ui-testing") -or
        $projectText.Contains("XCUITest")) {
        Add-Failure "工程出现 XCUITest target"
    }

    $sourceNames = @(
        "PhotoCleanupMVEApp.swift",
        "CleanupCoordinator.swift",
        "AssetModels.swift",
        "S3StateMachine.swift",
        "S4StateMachine.swift",
        "S5StateMachine.swift",
        "SessionPersistence.swift",
        "PhotoLibraryService.swift",
        "AssetSizeScanner.swift",
        "PhotoDeletionService.swift",
        "FreeDiskSpaceReader.swift",
        "S3View.swift",
        "S4View.swift",
        "S5View.swift",
        "ThumbnailView.swift",
        "L10n.swift",
        "Localizable.xcstrings",
        "S3StateMachineTests.swift",
        "SnapshotInvariantTests.swift",
        "VolumeFormattingTests.swift",
        "S4StateMachineTests.swift",
        "S5StateMachineTests.swift",
        "CollectionInvariantTests.swift",
        "TransitionTableGuardTests.swift",
        "CoverageGapTests.swift"
    )
    foreach ($sourceName in $sourceNames) {
        if (-not $projectText.Contains($sourceName)) {
            Add-Failure "工程未引用源码：$sourceName"
        }
    }
}

$schemeFile = Join-Path $projectRoot "PhotoCleanupMVE.xcodeproj/xcshareddata/xcschemes/PhotoCleanupMVE.xcscheme"
if (Test-Path -LiteralPath $schemeFile -PathType Leaf) {
    $schemeText = Get-Content -LiteralPath $schemeFile -Raw -Encoding UTF8
    if ($schemeText.Contains("UITest")) {
        Add-Failure "共享方案出现 UI 测试引用"
    }
}

$infoFile = Join-Path $projectRoot "PhotoCleanupMVE/Info.plist"
if (Test-Path -LiteralPath $infoFile -PathType Leaf) {
    try {
        [xml]$null = Get-Content -LiteralPath $infoFile -Raw -Encoding UTF8
    }
    catch {
        Add-Failure "Info.plist 不是合法 XML：$($_.Exception.Message)"
    }
}

$workflowFile = Join-Path $projectRoot ".github/workflows/ci.yml"
if (Test-Path -LiteralPath $workflowFile -PathType Leaf) {
    $workflowText = Get-Content -LiteralPath $workflowFile -Raw -Encoding UTF8

    $approvedActionReferences = @(
        "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
    )
    $actionUseMatches = [regex]::Matches($workflowText, "(?m)^\s*uses\s*:\s*([^\s#]+)")
    if ($actionUseMatches.Count -ne 1) {
        Add-Failure "CI 外部 GitHub Action 引用数量不是 1"
    }
    foreach ($actionUseMatch in $actionUseMatches) {
        $actionReference = $actionUseMatch.Groups[1].Value
        if ($approvedActionReferences -notcontains $actionReference) {
            Add-Failure "CI 引用了未经本工程审查或未锁定完整提交哈希的外部 GitHub Action：$actionReference"
        }
    }
    $requiredWorkflowValues = @(
        "bash Scripts/test-xcode.sh",
        "CODE_SIGNING_ALLOWED=NO",
        "CODE_SIGNING_REQUIRED=NO",
        "PhotoCleanupMVE-unsigned.ipa",
        "id: package",
        "git rev-parse --short=12 HEAD",
        'name: ${{ steps.package.outputs.artifact_name }}',
        "path: BuildArtifacts/PhotoCleanupMVE-unsigned.ipa",
        "if-no-files-found: error",
        "compression-level: 0",
        "overwrite: false",
        "include-hidden-files: false",
        "archive: true"
    )
    foreach ($value in $requiredWorkflowValues) {
        if (-not $workflowText.Contains($value)) {
            Add-Failure "CI 配置缺少：$value"
        }
    }
}

$pngFile = Join-Path $projectRoot "PhotoCleanupMVE/Assets.xcassets/RECENTLY_DELETED_PLACEHOLDER.imageset/RECENTLY_DELETED_PLACEHOLDER.png"
if (Test-Path -LiteralPath $pngFile -PathType Leaf) {
    $bytes = [System.IO.File]::ReadAllBytes($pngFile)
    $signature = [byte[]](137, 80, 78, 71, 13, 10, 26, 10)
    if ($bytes.Length -lt $signature.Length) {
        Add-Failure "PLACEHOLDER 图片不是合法 PNG：文件过短"
    }
    else {
        for ($index = 0; $index -lt $signature.Length; $index++) {
            if ($bytes[$index] -ne $signature[$index]) {
                Add-Failure "PLACEHOLDER 图片不是合法 PNG：签名错误"
                break
            }
        }
    }
}

$placeholderContentsFile = Join-Path $projectRoot "PhotoCleanupMVE/Assets.xcassets/RECENTLY_DELETED_PLACEHOLDER.imageset/Contents.json"
if (Test-Path -LiteralPath $placeholderContentsFile -PathType Leaf) {
    try {
        $placeholderContents = Get-Content -LiteralPath $placeholderContentsFile -Raw -Encoding UTF8 |
            ConvertFrom-Json
        $placeholderLocales = @(
            $placeholderContents.images |
                ForEach-Object { $_.locale } |
                Sort-Object -Unique
        )
        $placeholderFilenames = @(
            $placeholderContents.images |
                Where-Object { $_.PSObject.Properties.Name -contains "filename" } |
                ForEach-Object { $_.filename }
        )
        if ($placeholderLocales.Count -ne 1 -or $placeholderLocales[0] -ne "zh-Hans") {
            Add-Failure "PLACEHOLDER 图片语言条目必须且只能是 zh-Hans"
        }
        if ($placeholderFilenames.Count -ne 1 -or
            $placeholderFilenames[0] -ne "RECENTLY_DELETED_PLACEHOLDER.png") {
            Add-Failure "PLACEHOLDER 必须只填一份现有 zh-Hans PNG"
        }
    }
    catch {
        Add-Failure "PLACEHOLDER Contents.json 无法解析：$($_.Exception.Message)"
    }
}

$swiftDirectories = @(
    (Join-Path $projectRoot "PhotoCleanupMVE/App"),
    (Join-Path $projectRoot "PhotoCleanupMVE/Core"),
    (Join-Path $projectRoot "PhotoCleanupMVE/Services"),
    (Join-Path $projectRoot "PhotoCleanupMVE/Features")
)
$swiftFiles = @()
foreach ($directory in $swiftDirectories) {
    if (Test-Path -LiteralPath $directory -PathType Container) {
        $swiftFiles += Get-ChildItem -LiteralPath $directory -Filter "*.swift" -File -Recurse
    }
}

$productSourceFiles = @(
    $swiftFiles |
        ForEach-Object { $_.FullName.Substring($projectRoot.Length + 1).Replace("\", "/") }
)
foreach ($baselineProductSourceFile in $baselineProductSourceFiles) {
    if ($productSourceFiles -cnotcontains $baselineProductSourceFile) {
        Add-Failure "产品源码文件清单缺少基线文件：$baselineProductSourceFile"
    }
}

if ($swiftFiles.Count -gt 0) {
    $networkPattern = "\b(URLSession|NWConnection|NetworkExtension|Alamofire|Moya)\b|import\s+Network\b"
    $accountPattern = "\b(AuthenticationServices|ASAuthorization|StoreKit)\b"
    $networkHits = Select-String -LiteralPath $swiftFiles.FullName -Pattern $networkPattern
    $accountHits = Select-String -LiteralPath $swiftFiles.FullName -Pattern $accountPattern
    if ($networkHits) {
        Add-Failure "产品源码出现联网能力：$($networkHits[0].Path):$($networkHits[0].LineNumber)"
    }
    if ($accountHits) {
        Add-Failure "产品源码出现账号或商店能力：$($accountHits[0].Path):$($accountHits[0].LineNumber)"
    }

    $l3DefaultPatterns = @(
        "(?i)\b(?:static\s+)?(?:let|var)\s+\w*pollingWindow\w*\s*=\s*[-+]?[0-9]",
        "(?i)\b(?:static\s+)?(?:let|var)\s+\w*samplingInterval\w*\s*=\s*[-+]?[0-9]",
        "(?i)\b(?:static\s+)?(?:let|var)\s+\w*(?:stability|start)Threshold\w*\s*=\s*[-+]?[0-9]",
        "(?i)\b(?:static\s+)?(?:let|var)\s+\w*baselineTiming\w*\s*=\s*\."
    )
    foreach ($pattern in $l3DefaultPatterns) {
        $hits = Select-String -LiteralPath $swiftFiles.FullName -Pattern $pattern
        if ($hits) {
            Add-Failure "产品源码疑似写死 L3 未定项：$($hits[0].Path):$($hits[0].LineNumber)"
        }
    }

    $forbiddenS5Patterns = @(
        "S5-T2",
        "S5-T3",
        "L3窗口上限",
        "L3采样间隔",
        "L3稳定判据",
        "L3启动阈值",
        "L3基线时机"
    )
    foreach ($pattern in $forbiddenS5Patterns) {
        $hits = Select-String -LiteralPath $swiftFiles.FullName -SimpleMatch -Pattern $pattern
        if ($hits) {
            Add-Failure "产品源码出现禁止的 S5 轮询实现标记：$($hits[0].Path):$($hits[0].LineNumber)"
        }
    }

    $debugEntries = @(
        Select-String -LiteralPath $swiftFiles.FullName -Pattern "static\s+let\s+debugAssetLimit\s*=\s*\d+"
    )
    if ($debugEntries.Count -ne 1) {
        Add-Failure "调试入口常量定义数必须为 1，实际为 $($debugEntries.Count)"
    }
    $debugEntryUses = @(
        Select-String -LiteralPath $swiftFiles.FullName -Pattern "limit:\s*Self\.debugAssetLimit"
    )
    if ($debugEntryUses.Count -ne 1) {
        Add-Failure "调试入口取样调用必须且只能引用常量 1 次，实际为 $($debugEntryUses.Count)"
    }

    $removedS3Patterns = @(
        ("submission" + "Limit"),
        ("over" + "Limit"),
        ("S3-" + "3")
    )
    foreach ($pattern in $removedS3Patterns) {
        $hits = Select-String -LiteralPath $swiftFiles.FullName -SimpleMatch -Pattern $pattern
        if ($hits) {
            Add-Failure "S3 已删除的数量上限实现仍有残留：$($hits[0].Path):$($hits[0].LineNumber)"
        }
    }

    $l3GateMarker = Select-String -LiteralPath $swiftFiles.FullName -Pattern "blockedByUndecidedThreshold\s*=\s*true"
    if (-not $l3GateMarker) {
        Add-Failure "缺少 L3 展示分支被未定规格阻断的显式标记"
    }

    $l3NumericGate = Select-String -LiteralPath $swiftFiles.FullName -Pattern "(?i)(?:l3DisplayThreshold|L3显示门槛)\s*(?:=|:)\s*[-+]?[0-9]"
    if ($l3NumericGate) {
        Add-Failure "L3 显示门槛被写入数值：$($l3NumericGate[0].Path):$($l3NumericGate[0].LineNumber)"
    }
}

$testDirectory = Join-Path $projectRoot "PhotoCleanupMVETests"
if (Test-Path -LiteralPath $testDirectory -PathType Container) {
    $testFiles = Get-ChildItem -LiteralPath $testDirectory -Filter "*.swift" -File
    if ($testFiles.Count -gt 0) {
        $testCases = Select-String -LiteralPath $testFiles.FullName -Pattern "^\s*func\s+test"
        $minimumTestMethodCount = 189
        if ($testCases.Count -lt $minimumTestMethodCount) {
            Add-Failure "XCTest 测试函数不得少于 $minimumTestMethodCount 个，实际为 $($testCases.Count) 个"
        }

        $s3Cells = Select-String -LiteralPath (Join-Path $testDirectory "S3StateMachineTests.swift") -Pattern "testCell([0-9]{2})" -AllMatches
        $s3CellNumbers = @($s3Cells.Matches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $expectedS3CellNumbers = @("01", "02", "03", "04", "05", "07", "08", "11", "12", "14")
        if (($s3CellNumbers -join ",") -ne ($expectedS3CellNumbers -join ",")) {
            Add-Failure "S3 可达单元格映射不符合三状态基线：$($s3CellNumbers -join ', ')"
        }

        $s4Cells = Select-String -LiteralPath (Join-Path $testDirectory "S4StateMachineTests.swift") -Pattern "testReachable([0-9]{2})" -AllMatches
        $s4CellNumbers = @($s4Cells.Matches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        if ($s4CellNumbers.Count -ne 22) {
            Add-Failure "S4 可达单元格映射为 $($s4CellNumbers.Count)/22"
        }

        $s5Cells = Select-String -LiteralPath (Join-Path $testDirectory "S5StateMachineTests.swift") -Pattern "testCell([0-9]{2})" -AllMatches
        $s5CellNumbers = @($s5Cells.Matches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        if ($s5CellNumbers.Count -ne 15) {
            Add-Failure "S5 原有可达单元格映射为 $($s5CellNumbers.Count)/15"
        }

        $s5TestText = Get-Content -LiteralPath (Join-Path $testDirectory "S5StateMachineTests.swift") -Raw -Encoding UTF8
        $requiredCancellationTests = @(
            "testCancellationDoesNotReadFreeDiskStrictGB",
            "testCancellationDoesNotShowL3",
            "testCancellationDoesNotShowSystemErrorDomainOrCode",
            "testCancellationDoesNotShowRecentlyDeletedConfirmationAction",
            "testCancellationVisibleCopyAvoidsFailureAndIncompleteWording"
        )
        foreach ($testName in $requiredCancellationTests) {
            if (-not $s5TestText.Contains($testName)) {
                Add-Failure "S5-C 禁用项缺少测试：$testName"
            }
        }
    }
}

$hardcodedStringScanner = Join-Path $projectRoot "Scripts/scan-hardcoded-user-visible-strings.ps1"
if (Test-Path -LiteralPath $hardcodedStringScanner -PathType Leaf) {
    & $hardcodedStringScanner
    if ($LASTEXITCODE -ne 0) {
        Add-Failure "用户可见硬编码字符串扫描未通过"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "结构自验失败，共 $($failures.Count) 项：" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "结构自验通过：文件、工程配置、String Catalog、PNG、禁联网门禁、硬编码扫描及不少于 189 项测试的数量门禁均符合要求。" -ForegroundColor Green
