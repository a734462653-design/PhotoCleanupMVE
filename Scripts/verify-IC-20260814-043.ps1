param(
    [switch]$允许未提交交付物,
    [switch]$允许待回填CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$工作区 = Split-Path -Parent $项目根
$源码路径 = Join-Path $项目根 "PhotoCleanupMVE/Core/SessionStore.swift"
$测试路径 = Join-Path $项目根 "PhotoCleanupMVETests/SessionStoreTests.swift"
$工程路径 = Join-Path $项目根 "PhotoCleanupMVE.xcodeproj/project.pbxproj"
$报告路径 = Join-Path $项目根 "Reports/IC-20260814-043-SELF-VERIFICATION.md"
$规格路径 = Join-Path $工作区 "SPEC-S1-20260813.v3.md"
$基线提交 = "cff06d109e8cf3d77c2238b1da3eb54bd009b3c0"
$规格摘要 = "F2565629CE6E9BD1ABB7C6841C73460C3E7E8F252A21A70D6E01893B87189238"
$基线测试总数 = 189
$新增测试总数 = 14
$当前测试总数 = 203
$检查总数 = 0
$失败清单 = [System.Collections.Generic.List[string]]::new()

$允许改动 = @(
    "PhotoCleanupMVE.xcodeproj/project.pbxproj",
    "PhotoCleanupMVE/Core/SessionStore.swift",
    "PhotoCleanupMVETests/SessionStoreTests.swift",
    "Scripts/verify-IC-20260814-043.ps1",
    "Reports/IC-20260814-043-SELF-VERIFICATION.md"
)

$保护路径 = @(
    ".github/workflows/ci.yml",
    "PhotoCleanupMVE/App/CleanupCoordinator.swift",
    "PhotoCleanupMVE/Core/S3StateMachine.swift",
    "PhotoCleanupMVE/Core/S4StateMachine.swift",
    "PhotoCleanupMVE/Core/S5StateMachine.swift",
    "PhotoCleanupMVETests/S3StateMachineTests.swift",
    "PhotoCleanupMVETests/S4StateMachineTests.swift",
    "PhotoCleanupMVETests/S5StateMachineTests.swift",
    "PhotoCleanupMVE/Info.plist",
    "PhotoCleanupMVE/Localizable.xcstrings"
)

$预期测试方法 = @(
    "testIC043_001IntersectionReturnMakesUnionEqualReturnedSet",
    "testIC043_002GroupCountsSumEqualsMergedDeletionCount",
    "testIC043_003FirstMarkedRangeRemainsSingleValued",
    "testIC043_004FirstMarkedRangeKeyIsRemovedOnlyAfterEveryRangeUnmarks",
    "testIC043_005DuplicateAcrossRangesCountsOnceGloballyAndOncePerRange",
    "testIC043_006ProcessedAssetsUsePrefixWhenSortOrderMatchesRecord",
    "testIC043_007ProcessedAssetsUseSuffixWhenSortOrderFlips",
    "testIC043_008EmptyS3ReturnClearsEveryPendingSetAndOwnershipKey",
    "testIC043_009AllEmptyRangeSetsProduceEmptyDerivedValues",
    "testIC043_010NeverEnteredRangeHasNoStoredStateAndEmptyDerivedValues",
    "testIC043_011InvalidS2ReturnLeavesWholeStoreUnchanged",
    "testIC043_012ValidS2ReturnAtomicallyWritesPendingSetAndContinuation",
    "testIC043_013S3SubmissionContainsStablePartitionNamesAndCounts",
    "testIC043_014InvalidS3ReturnLeavesWholeStoreUnchanged"
)

function 检查 {
    param(
        [bool]$条件,
        [string]$说明
    )

    $script:检查总数++
    if (-not $条件) {
        $script:失败清单.Add($说明)
    }
}

function 调用Git {
    param([string[]]$参数)

    Push-Location $项目根
    try {
        $输出 = @(& git @参数 2>&1)
        $退出码 = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($退出码 -ne 0) {
        throw "Git 命令执行失败：git $($参数 -join ' ')；输出：$($输出 -join ' ')"
    }
    return @($输出 | ForEach-Object { [string]$_ })
}

function 集合相同 {
    param(
        [object[]]$左侧,
        [object[]]$右侧
    )

    $仅左侧 = @($左侧 | Where-Object { $右侧 -cnotcontains $_ })
    $仅右侧 = @($右侧 | Where-Object { $左侧 -cnotcontains $_ })
    return $仅左侧.Count -eq 0 -and $仅右侧.Count -eq 0
}

$必需文件 = @(
    $源码路径,
    $测试路径,
    $工程路径,
    $报告路径,
    $PSCommandPath
)
foreach ($路径 in $必需文件) {
    检查 (Test-Path -LiteralPath $路径 -PathType Leaf) "缺少必需文件：$路径"
}

$基线类型 = @(调用Git @("cat-file", "-t", $基线提交))[0]
检查 ($基线类型 -ceq "commit") "任务基线不是 Git 提交"
Push-Location $项目根
try {
    & git merge-base --is-ancestor $基线提交 HEAD
    $基线是祖先 = $LASTEXITCODE -eq 0
}
finally {
    Pop-Location
}
检查 $基线是祖先 "当前 HEAD 不是任务基线的后代"

if (Test-Path -LiteralPath $规格路径 -PathType Leaf) {
    $实际规格摘要 = (Get-FileHash -LiteralPath $规格路径 -Algorithm SHA256).Hash
    检查 ($实际规格摘要 -ceq $规格摘要) "输入 SPEC 摘要与任务卡不一致"
}
else {
    $报告文本 = Get-Content -LiteralPath $报告路径 -Raw -Encoding UTF8
    检查 (
        $报告文本.Contains("SPEC-S1-20260813.v3.md") -and
        $报告文本.Contains($规格摘要)
    ) "仓库外 SPEC 不存在，且报告中没有固定摘要证据"
}

$基线测试行 = @(调用Git @(
    "grep",
    "-n",
    "-E",
    "^[[:space:]]*func[[:space:]]+test",
    $基线提交,
    "--",
    "PhotoCleanupMVETests"
))
检查 ($基线测试行.Count -eq $基线测试总数) "基线 XCTest 应为 $基线测试总数 个，实际为 $($基线测试行.Count) 个"

$测试文件 = @(Get-ChildItem -LiteralPath (Split-Path -Parent $测试路径) -Filter "*.swift" -File)
$测试匹配 = @(
    Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+(test[A-Za-z0-9_]+)\s*\('
)
$测试方法 = @($测试匹配 | ForEach-Object { $_.Matches[0].Groups[1].Value })
$新增测试匹配 = @(
    Select-String -LiteralPath $测试路径 -Pattern '^\s*func\s+(testIC043_[A-Za-z0-9_]+)\s*\('
)
$新增测试方法 = @($新增测试匹配 | ForEach-Object { $_.Matches[0].Groups[1].Value })

检查 ($测试方法.Count -eq $当前测试总数) "当前 XCTest 应为 $当前测试总数 个，实际为 $($测试方法.Count) 个"
检查 ((@($测试方法 | Sort-Object -Unique)).Count -eq $当前测试总数) "XCTest 方法名存在重复"
检查 ($新增测试方法.Count -eq $新增测试总数) "本卡 XCTest 应为 $新增测试总数 个，实际为 $($新增测试方法.Count) 个"
检查 (集合相同 $新增测试方法 $预期测试方法) "本卡编号 XCTest 方法集合不匹配"

$测试文本 = Get-Content -LiteralPath $测试路径 -Raw -Encoding UTF8
检查 (-not $测试文本.Contains("XCTSkip")) "本卡测试不得使用 XCTSkip"
foreach ($编号 in 1..14) {
    $编号文本 = "{0:D3}" -f $编号
    $编号方法 = @($新增测试方法 | Where-Object { $_ -cmatch "^testIC043_${编号文本}" })
    检查 ($编号方法.Count -eq 1) "IC043-$编号文本 应且只能对应一个专项测试方法"
    检查 ($测试文本.Contains("IC043-$编号文本：")) "测试文件缺少 IC043-$编号文本 的规格回指注释"
}

$测试关键断言 = @(
    'XCTAssertEqual(store.allPendingDeletionAssetIDs, ["资产-B", "资产-C"])',
    "submission.assetCountByRangeID.values.reduce(0, +)",
    'store.firstMarkedRangeIDByAssetID["资产-共享"]',
    'store.pendingDeletionCount(for: "范围-月")',
    "currentSortOrder: .newestFirst",
    "currentSortOrder: .oldestFirst",
    "store.applyS2Return(returned, entryContext: context)",
    "candidate.applyS3Return(returned)"
)
foreach ($断言 in $测试关键断言) {
    检查 ($测试文本.Contains($断言)) "测试文件缺少关键断言或调用：$断言"
}

$源码文本 = Get-Content -LiteralPath $源码路径 -Raw -Encoding UTF8
$禁止依赖 = @(
    "import Photos",
    "import PhotoKit",
    "import SwiftUI",
    "import UIKit",
    "SessionPersistence",
    "ObservableObject",
    "@Published",
    "NavigationStack",
    "CleanupRoute"
)
foreach ($禁止项 in $禁止依赖) {
    检查 (-not $源码文本.Contains($禁止项)) "SessionStore 出现禁止依赖或 UI 类型：$禁止项"
}
检查 ($源码文本.Contains("typealias AssetID = String")) "资产标识未明确使用字符串"
检查 ($源码文本.Contains("private struct State")) "M、K、F 未封装在单一内部状态中"
检查 ($源码文本.Contains("let sessionID: String")) "缺少稳定 sessionID"
检查 ($源码文本.Contains("var pendingDeletionAssetIDsByRangeID")) "缺少范围级待删映射 M"
检查 ($源码文本.Contains("var continuationsByRangeID")) "缺少范围级续接映射 K"
检查 ($源码文本.Contains("var firstMarkedRangeIDByAssetID")) "缺少跨范围归属映射 F"
检查 ($源码文本.Contains("var allPendingDeletionAssetIDs")) "缺少 D_全部 派生量"
检查 ($源码文本.Contains("func pendingDeletionCount")) "缺少待删计数派生量"
检查 ($源码文本.Contains("func processedAssetIDs")) "缺少已处理派生量"
检查 ($源码文本.Contains("var pendingDeletionGroupsByRangeID")) "缺少分组派生量"
检查 ($源码文本.Contains("func makeS3Submission")) "缺少 S3 提交数据形成方法"
检查 ($源码文本.Contains("func applyS2Return")) "缺少 S2 返回写回方法"
检查 ($源码文本.Contains("func applyS3Return")) "缺少 S3 返回交集更新方法"

$工程文本 = Get-Content -LiteralPath $工程路径 -Raw -Encoding UTF8
检查 (([regex]::Matches($工程文本, "10000000000000000000001F")).Count -eq 3) "SessionStore.swift 的工程文件引用数量不正确"
检查 (([regex]::Matches($工程文本, "20000000000000000000001C")).Count -eq 2) "SessionStore.swift 未且只未加入一次应用源码阶段"
检查 (([regex]::Matches($工程文本, "100000000000000000000020")).Count -eq 3) "SessionStoreTests.swift 的工程文件引用数量不正确"
检查 (([regex]::Matches($工程文本, "20000000000000000000001D")).Count -eq 2) "SessionStoreTests.swift 未且只未加入一次测试源码阶段"

$功能视图路径 = @(调用Git @("ls-tree", "-r", "--name-only", $基线提交, "--", "PhotoCleanupMVE/Features"))
$保护路径 += $功能视图路径
$保护路径 = @($保护路径 | Sort-Object -Unique)
foreach ($路径 in $保护路径) {
    $基线Blob = @(调用Git @("rev-parse", "${基线提交}:$路径"))[0]
    $当前Blob = @(调用Git @("rev-parse", "HEAD:$路径"))[0]
    $工作树Blob = @(调用Git @("hash-object", "--", $路径))[0]
    检查 ($当前Blob -ceq $基线Blob) "当前 HEAD 的受保护 Git blob 已变化：$路径"
    检查 ($工作树Blob -ceq $基线Blob) "工作树的受保护 Git blob 已变化：$路径"
}

$改动路径 = @(
    @(调用Git @("diff", "--name-only", $基线提交, "HEAD", "--")) +
    @(调用Git @("diff", "--name-only", "--")) +
    @(调用Git @("diff", "--cached", "--name-only", "--")) +
    @(调用Git @("ls-files", "--others", "--exclude-standard")) |
        Where-Object { $_ } |
        Sort-Object -Unique
)
foreach ($路径 in $改动路径) {
    检查 ($允许改动 -ccontains $路径) "出现范围外改动：$路径"
}
检查 (集合相同 $改动路径 $允许改动) "改动路径集合与本卡五个必要路径不一致"

$手势演示路径 = @(调用Git @("ls-files", "--", "*PhotoCleanupGestureDemo*"))
检查 ($手势演示路径.Count -eq 0) "仓库引入了 PhotoCleanupGestureDemo 内容"
$依赖路径 = @($改动路径 | Where-Object {
    $_ -cmatch '(^|/)(Package\.swift|Package\.resolved|Podfile|Podfile\.lock|Cartfile|Cartfile\.resolved)$'
})
检查 ($依赖路径.Count -eq 0) "本卡修改了第三方依赖声明"

$未跟踪路径 = @(调用Git @("ls-files", "--others", "--exclude-standard"))
if ($允许未提交交付物) {
    foreach ($路径 in $未跟踪路径) {
        检查 ($允许改动 -ccontains $路径) "出现非交付物未跟踪条目：$路径"
    }
}
else {
    检查 ($未跟踪路径.Count -eq 0) "本卡完成态仍有未跟踪条目"
    $工作树状态 = @(调用Git @("status", "--porcelain"))
    检查 ($工作树状态.Count -eq 0) "本卡完成态工作树不干净"
    foreach ($路径 in $允许改动) {
        $已追踪 = @(调用Git @("ls-files", "--error-unmatch", "--", $路径))
        检查 ($已追踪.Count -eq 1) "完成态交付路径未被 Git 追踪：$路径"
    }
}

$报告文本 = Get-Content -LiteralPath $报告路径 -Raw -Encoding UTF8
$报告固定证据 = @(
    "IC-20260814-043-session-store-core",
    $基线提交,
    $规格摘要,
    "| 新增 XCTest | 14 |",
    "| XCTest 总数 | 203 |"
)
foreach ($证据 in $报告固定证据) {
    检查 ($报告文本.Contains($证据)) "自验报告缺少固定证据：$证据"
}

if ($允许待回填CI) {
    检查 ($报告文本.Contains("CI 结果待本次推送回填")) "CI 前报告缺少待回填标记"
}
else {
    检查 ($报告文本.Contains("| 失败 | 0 |")) "最终报告缺少 0 失败证据"
    检查 ($报告文本.Contains("| unexpected | 0 |")) "最终报告缺少 0 unexpected 证据"
    检查 ($报告文本 -cmatch '受验提交\s*\|\s*`[0-9a-f]{40}`') "最终报告缺少 CI 受验提交"
    检查 ($报告文本 -cmatch 'CI 运行\s*\|\s*`[^`]+#\d+`') "最终报告缺少 CI 运行编号"
    检查 ($报告文本 -cmatch 'https://github\.com/[^\s)]+/actions/runs/\d+') "最终报告缺少 CI 运行链接"
    检查 ($报告文本.Contains("Release 构建通过")) "最终报告缺少 Release 构建通过证据"
    检查 ($报告文本.Contains("未签名 IPA 产出通过")) "最终报告缺少未签名 IPA 证据"
}

$Xcode命令 = Get-Command xcodebuild -ErrorAction SilentlyContinue
if ($null -ne $Xcode命令) {
    & bash (Join-Path $PSScriptRoot "test-xcode.sh")
    检查 ($LASTEXITCODE -eq 0) "全量 XCTest 执行失败"
}
elseif (-not $允许待回填CI) {
    检查 ($报告文本.Contains("全量 XCTest 通过")) "当前无 Xcode，且最终报告缺少全量 XCTest 通过证据"
}

if ($失败清单.Count -gt 0) {
    Write-Host "IC-20260814-043 自验失败：共执行 $检查总数 项检查，失败 $($失败清单.Count) 项。" -ForegroundColor Red
    foreach ($失败项 in $失败清单) {
        Write-Host "  - $失败项" -ForegroundColor Red
    }
    exit 1
}

Write-Host "IC-20260814-043 自验通过：共执行 $检查总数 项检查。" -ForegroundColor Green
if ($允许待回填CI) {
    Write-Host "统计：基线 XCTest 189；新增 14；总数 203；运行态失败与 unexpected 待 CI 回填。"
}
else {
    Write-Host "统计：基线 XCTest 189；新增 14；总数 203；失败 0；unexpected 0。"
}
Write-Host "保护：范围外 Git blob、禁用依赖、改动白名单与未跟踪条目均符合本卡约束。"
