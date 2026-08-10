param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message)
}

$requiredFiles = @(
    ".gitattributes",
    "PhotoCleanupMVE.xcodeproj/project.pbxproj",
    "PhotoCleanupMVE.xcodeproj/xcshareddata/xcschemes/PhotoCleanupMVE.xcscheme",
    "PhotoCleanupMVE/Info.plist",
    "PhotoCleanupMVE/Assets.xcassets/Contents.json",
    "PhotoCleanupMVE/Assets.xcassets/RECENTLY_DELETED_PLACEHOLDER.imageset/Contents.json",
    "PhotoCleanupMVE/Assets.xcassets/RECENTLY_DELETED_PLACEHOLDER.imageset/RECENTLY_DELETED_PLACEHOLDER.png",
    "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift",
    "PhotoCleanupMVE/App/CleanupCoordinator.swift",
    "PhotoCleanupMVE/Core/AssetModels.swift",
    "PhotoCleanupMVE/Core/S3StateMachine.swift",
    "PhotoCleanupMVE/Core/S4StateMachine.swift",
    "PhotoCleanupMVE/Core/S5StateMachine.swift",
    "PhotoCleanupMVE/Core/SessionPersistence.swift",
    "PhotoCleanupMVE/Services/PhotoLibraryService.swift",
    "PhotoCleanupMVE/Services/AssetSizeScanner.swift",
    "PhotoCleanupMVE/Services/PhotoDeletionService.swift",
    "PhotoCleanupMVE/Features/S3/S3View.swift",
    "PhotoCleanupMVE/Features/S4/S4View.swift",
    "PhotoCleanupMVE/Features/S5/S5View.swift",
    "PhotoCleanupMVE/Features/Shared/ThumbnailView.swift",
    "PhotoCleanupMVETests/S3StateMachineTests.swift",
    "PhotoCleanupMVETests/SnapshotInvariantTests.swift",
    "PhotoCleanupMVETests/VolumeFormattingTests.swift",
    "PhotoCleanupMVETests/S4StateMachineTests.swift",
    "PhotoCleanupMVETests/S5StateMachineTests.swift",
    "PhotoCleanupMVETests/CollectionInvariantTests.swift",
    "Scripts/test-xcode.sh",
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
        "S3View.swift",
        "S4View.swift",
        "S5View.swift",
        "ThumbnailView.swift",
        "S3StateMachineTests.swift",
        "SnapshotInvariantTests.swift",
        "VolumeFormattingTests.swift",
        "S4StateMachineTests.swift",
        "S5StateMachineTests.swift",
        "CollectionInvariantTests.swift"
    )
    foreach ($sourceName in $sourceNames) {
        if (-not $projectText.Contains($sourceName)) {
            Add-Failure "工程未引用源码：$sourceName"
        }
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
        "freeDiskStrictGB",
        "L3窗口上限",
        "L3采样间隔",
        "L3稳定判据",
        "L3启动阈值",
        "L3基线读数",
        "L3基线时机"
    )
    foreach ($pattern in $forbiddenS5Patterns) {
        $hits = Select-String -LiteralPath $swiftFiles.FullName -SimpleMatch -Pattern $pattern
        if ($hits) {
            Add-Failure "产品源码出现本卡禁止的 S5 轮询实现标记：$($hits[0].Path):$($hits[0].LineNumber)"
        }
    }

    $debugEntry = Select-String -LiteralPath $swiftFiles.FullName -Pattern "static\s+let\s+debugAssetLimit\s*=\s*20"
    if (-not $debugEntry) {
        Add-Failure "调试入口常量缺失或默认值不是 20"
    }

    $submissionLimit = Select-String -LiteralPath $swiftFiles.FullName -Pattern "static\s+let\s+submissionLimit\s*=\s*200"
    if (-not $submissionLimit) {
        Add-Failure "S3 单次提交上限缺失或不是 200"
    }
}

$testDirectory = Join-Path $projectRoot "PhotoCleanupMVETests"
if (Test-Path -LiteralPath $testDirectory -PathType Container) {
    $testFiles = Get-ChildItem -LiteralPath $testDirectory -Filter "*.swift" -File
    if ($testFiles.Count -gt 0) {
        $testCases = Select-String -LiteralPath $testFiles.FullName -Pattern "^\s*func\s+test"
        if ($testCases.Count -lt 51) {
            Add-Failure "XCTest 测试函数仅 $($testCases.Count) 个，少于 51 个可达迁移单元格"
        }

        $s3Cells = Select-String -LiteralPath (Join-Path $testDirectory "S3StateMachineTests.swift") -Pattern "testCell([0-9]{2})" -AllMatches
        $s3CellNumbers = @($s3Cells.Matches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        if ($s3CellNumbers.Count -ne 14) {
            Add-Failure "S3 可达单元格映射为 $($s3CellNumbers.Count)/14"
        }

        $s4Cells = Select-String -LiteralPath (Join-Path $testDirectory "S4StateMachineTests.swift") -Pattern "testReachable([0-9]{2})" -AllMatches
        $s4CellNumbers = @($s4Cells.Matches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        if ($s4CellNumbers.Count -ne 22) {
            Add-Failure "S4 可达单元格映射为 $($s4CellNumbers.Count)/22"
        }

        $s5Cells = Select-String -LiteralPath (Join-Path $testDirectory "S5StateMachineTests.swift") -Pattern "testCell([0-9]{2})" -AllMatches
        $s5CellNumbers = @($s5Cells.Matches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        if ($s5CellNumbers.Count -ne 15) {
            Add-Failure "S5 限定三状态可达单元格映射为 $($s5CellNumbers.Count)/15"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "结构自验失败，共 $($failures.Count) 项：" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "结构自验通过：文件、工程配置、PNG 签名、禁联网门禁及测试数量均符合要求。" -ForegroundColor Green
