param(
    [switch]$允许未提交交付物,
    [switch]$允许待回填CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$工作区 = Split-Path -Parent $项目根
$状态机路径 = Join-Path $项目根 "PhotoCleanupMVE/Core/S1StateMachine.swift"
$视图路径 = Join-Path $项目根 "PhotoCleanupMVE/Features/S1/S1View.swift"
$服务路径 = Join-Path $项目根 "PhotoCleanupMVE/Services/PhotoLibraryService.swift"
$测试路径 = Join-Path $项目根 "PhotoCleanupMVETests/S1StateMachineTests.swift"
$目录路径 = Join-Path $项目根 "PhotoCleanupMVE/Localizable.xcstrings"
$工程路径 = Join-Path $项目根 "PhotoCleanupMVE.xcodeproj/project.pbxproj"
$报告路径 = Join-Path $项目根 "Reports/IC-20260814-046-SELF-VERIFICATION.md"
$规格路径 = Join-Path $工作区 "SPEC-S1-20260813.v3.md"
$实际基线提交 = "7fcbe9c37c66094c0c2e3c0d61315e4646fa5e3d"
$上游测试基线 = 203
$实际起点测试总数 = 208
$新增测试总数 = 18
$当前测试总数 = 226
$规格摘要 = "F2565629CE6E9BD1ABB7C6841C73460C3E7E8F252A21A70D6E01893B87189238"
$检查总数 = 0
$失败清单 = [System.Collections.Generic.List[string]]::new()

$允许改动 = @(
    "PhotoCleanupMVE.xcodeproj/project.pbxproj",
    "PhotoCleanupMVE/Core/S1StateMachine.swift",
    "PhotoCleanupMVE/Features/S1/S1View.swift",
    "PhotoCleanupMVE/Services/PhotoLibraryService.swift",
    "PhotoCleanupMVE/Localizable.xcstrings",
    "PhotoCleanupMVETests/S1StateMachineTests.swift",
    "Scripts/verify-IC-20260814-046.ps1",
    "Reports/IC-20260814-046-SELF-VERIFICATION.md"
)

$保护路径 = @(
    ".github/workflows/ci.yml",
    "Scripts/selfcheck.ps1",
    "PhotoCleanupMVE/App/CleanupCoordinator.swift",
    "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift",
    "PhotoCleanupMVE/Core/SessionStore.swift",
    "PhotoCleanupMVETests/SessionStoreTests.swift",
    "PhotoCleanupMVE/Core/S3StateMachine.swift",
    "PhotoCleanupMVE/Core/S4StateMachine.swift",
    "PhotoCleanupMVE/Core/S5StateMachine.swift",
    "PhotoCleanupMVETests/S3StateMachineTests.swift",
    "PhotoCleanupMVETests/S4StateMachineTests.swift",
    "PhotoCleanupMVETests/S5StateMachineTests.swift",
    "PhotoCleanupMVETests/S3ReturnRouteTests.swift",
    "PhotoCleanupMVE/Features/S3/S3View.swift",
    "PhotoCleanupMVE/Features/S4/S4View.swift",
    "PhotoCleanupMVE/Features/S5/S5View.swift"
)

$预期测试方法 = @(
    "testIC046_001InitialEntryReachesLoading",
    "testIC046_002SuccessfulNonemptyReadReachesReady",
    "testIC046_003SuccessfulEmptyReadReachesEmpty",
    "testIC046_004FailedReadReachesFailedWithDistinctReason",
    "testIC046_005GroupingSwitchAlwaysReturnsToLoadingAndPreservesSession",
    "testIC046_006SortSwitchPreservesLoadingAndSessionState",
    "testIC046_007StaleReadCompletionIsIgnoredAfterGroupingSwitch",
    "testIC046_008RetryFromFailureCreatesNewLoadingRequest",
    "testIC046_009LoadingFailedAndEmptyCannotFormS2Handoff",
    "testIC046_010ProcessedAssetsUsePrefixWhenOrdersMatch",
    "testIC046_011ProcessedAssetsUseSuffixWhenOrderFlips",
    "testIC046_012BadgeAlwaysUsesMergedDeletionSetCount",
    "testIC046_013S2HandoffContainsSixValidFields",
    "testIC046_014InvalidAOrDRejectsS2Handoff",
    "testIC046_015SortFlipsChronologicalRangesButNotAlbumRanges",
    "testIC046_016ObscurationBlocksInputsAndPreservesState",
    "testIC046_017S2ReturnWritesSessionWithoutChangingS1Parameters",
    "testIC046_018RangeRowContainsAllFourRequiredValues"
)

$未定项常量 = @(
    "item01InitialGroupingAndSort",
    "item02AuthorizationStates",
    "item03AlbumOrderingAndInclusion",
    "item04EmptyChronologicalRanges",
    "item05LongNameTruncation",
    "item06ZeroPendingAndProgressPresentation",
    "item07EmptyMergedDeletionTrashPresentation",
    "item08MergedDeletionSubmissionOrder",
    "item09FailureDetailAndRetryPolicy",
    "item10LoadingIndicator",
    "item11SessionPersistenceAndEnd",
    "item12S2ReturnValidationFailurePresentation",
    "item13ExternalPhotoLibraryChanges",
    "item14DuplicateRangeCountExplanation",
    "item14bS3GroupOrderingAndPaging",
    "item14cEmptyS3GroupPresentation",
    "item15EmptyAndFailureCopy",
    "item16RecommendedCleanupArea",
    "item17FileSizeSort"
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
    $状态机路径,
    $视图路径,
    $服务路径,
    $测试路径,
    $目录路径,
    $工程路径,
    $报告路径,
    $PSCommandPath
)
foreach ($路径 in $必需文件) {
    检查 (Test-Path -LiteralPath $路径 -PathType Leaf) "缺少必需文件：$路径"
}

$基线类型 = @(调用Git @("cat-file", "-t", $实际基线提交))[0]
检查 ($基线类型 -ceq "commit") "实际开发基线不是 Git 提交"
Push-Location $项目根
try {
    & git merge-base --is-ancestor $实际基线提交 HEAD
    $基线是祖先 = $LASTEXITCODE -eq 0
}
finally {
    Pop-Location
}
检查 $基线是祖先 "当前 HEAD 不是实际开发基线的后代"

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
    $实际基线提交,
    "--",
    "PhotoCleanupMVETests"
))
检查 ($基线测试行.Count -eq $实际起点测试总数) "实际起点 XCTest 应为 $实际起点测试总数 个，实际为 $($基线测试行.Count) 个"

$测试文件 = @(Get-ChildItem -LiteralPath (Split-Path -Parent $测试路径) -Filter "*.swift" -File)
$测试匹配 = @(
    Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+(test[A-Za-z0-9_]+)\s*\('
)
$测试方法 = @($测试匹配 | ForEach-Object { $_.Matches[0].Groups[1].Value })
$新增测试匹配 = @(
    Select-String -LiteralPath $测试路径 -Pattern '^\s*func\s+(testIC046_[A-Za-z0-9_]+)\s*\('
)
$新增测试方法 = @($新增测试匹配 | ForEach-Object { $_.Matches[0].Groups[1].Value })
检查 ($测试方法.Count -eq $当前测试总数) "当前 XCTest 应为 $当前测试总数 个，实际为 $($测试方法.Count) 个"
检查 ((@($测试方法 | Sort-Object -Unique)).Count -eq $当前测试总数) "XCTest 方法名存在重复"
检查 ($新增测试方法.Count -eq $新增测试总数) "本卡 XCTest 应为 $新增测试总数 个，实际为 $($新增测试方法.Count) 个"
检查 (集合相同 $新增测试方法 $预期测试方法) "本卡编号 XCTest 方法集合不匹配"

$测试文本 = Get-Content -LiteralPath $测试路径 -Raw -Encoding UTF8
检查 (-not $测试文本.Contains("XCTSkip")) "本卡测试不得使用 XCTSkip"
foreach ($编号 in 1..18) {
    $编号文本 = "{0:D3}" -f $编号
    $编号方法 = @($新增测试方法 | Where-Object { $_ -cmatch "^testIC046_${编号文本}" })
    检查 ($编号方法.Count -eq 1) "IC046-$编号文本 应且只能对应一个专项测试方法"
    检查 ($测试文本.Contains("IC046-$编号文本：")) "测试文件缺少 IC046-$编号文本 的规格回指注释"
}

$状态机文本 = Get-Content -LiteralPath $状态机路径 -Raw -Encoding UTF8
foreach ($状态标识 in @("S1-1", "S1-2", "S1-3", "S1-4")) {
    检查 ($状态机文本.Contains($状态标识)) "状态机缺少状态标识：$状态标识"
}
foreach ($维度 in @("case month", "case year", "case album", "case unclassified")) {
    检查 ($状态机文本.Contains($维度)) "状态机缺少分组维度：$维度"
}
foreach ($排序 in @("case newestFirst", "case oldestFirst")) {
    检查 ($状态机文本.Contains($排序)) "状态机缺少排序方式：$排序"
}
foreach ($常量 in $未定项常量) {
    $匹配数 = ([regex]::Matches($状态机文本, "static let $常量\s*=\s*S1UndecidedPlaceholder\.unresolved")).Count
    检查 ($匹配数 -eq 1) "未定项占位未且只未集中声明一次：$常量"
}
检查 ($状态机文本.Contains("func completeRangeRead")) "缺少范围读取完成迁移"
检查 ($状态机文本.Contains("func switchGroupingDimension")) "缺少 T 切换迁移"
检查 ($状态机文本.Contains("func switchSortOrder")) "缺少 O 切换迁移"
检查 ($状态机文本.Contains("func makeS2Handoff")) "缺少 S1 到 S2 构造逻辑"
检查 ($状态机文本.Contains("let sessionMergedPendingDeletionCount: Int")) "六字段交接缺少只读会话合并待删总数"
检查 ($状态机文本.Contains("sessionStore.allPendingDeletionAssetIDs.count")) "徽标数值未直接派生自 D_全部"

$服务文本 = Get-Content -LiteralPath $服务路径 -Raw -Encoding UTF8
检查 ($服务文本.Contains("func s1Ranges")) "PhotoLibraryService 缺少 S1 范围读取入口"
检查 ($服务文本.Contains("albumCollections: [PHAssetCollection]")) "相册范围读取未要求显式相册集合"
foreach ($维度分支 in @("case .month:", "case .year:", "case .album:", "case .unclassified:")) {
    检查 ($服务文本.Contains($维度分支)) "PhotoLibraryService 缺少读取分支：$维度分支"
}
foreach ($失败原因 in @(
    "authorizationNotDetermined",
    "authorizationDenied",
    "authorizationRestricted",
    "limitedAuthorizationPolicyUndecided",
    "missingCreationDate",
    "missingDisplayName"
)) {
    检查 ($状态机文本.Contains($失败原因) -and $服务文本.Contains($失败原因)) "读取失败未区分并上报：$失败原因"
}

$视图文本 = Get-Content -LiteralPath $视图路径 -Raw -Encoding UTF8
检查 (([regex]::Matches($视图文本, '#Preview\("S1-[1-4]"\)')).Count -eq 4) "S1 四状态独立预览数量不正确"
检查 ($视图文本.Contains("ForEach(S1GroupingDimension.allCases")) "视图未平铺四类分组维度"
检查 ($视图文本.Contains("ForEach(S1SortOrder.allCases")) "视图缺少排序切换控件"
检查 ($视图文本.Contains("List(machine.rangeRows)")) "视图缺少范围列表"
检查 ($视图文本.Contains("Text(String(machine.badgeCount))")) "垃圾桶徽标未显示纯数字"
检查 ($视图文本.Contains("row.displayName")) "范围项缺少显示名"
检查 ($视图文本.Contains("row.totalAssetCount")) "范围项缺少资产总数"
检查 ($视图文本.Contains("row.pendingDeletionCount")) "范围项缺少待删计数"
检查 ($视图文本.Contains("row.processedAssetCount")) "范围项缺少已处理进度"

$其他产品Swift = @(
    Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVE") -Filter "*.swift" -File -Recurse |
        Where-Object { $_.FullName -cne $视图路径 }
)
$视图引用 = @(
    Select-String -LiteralPath $其他产品Swift.FullName -SimpleMatch -Pattern "S1View"
)
检查 ($视图引用.Count -eq 0) "S1View 被现有产品源码或导航引用"

$工程文本 = Get-Content -LiteralPath $工程路径 -Raw -Encoding UTF8
foreach ($文件名 in @("S1StateMachine.swift", "S1View.swift", "S1StateMachineTests.swift")) {
    检查 ($工程文本.Contains($文件名)) "工程未引用新增文件：$文件名"
}
检查 (([regex]::Matches($工程文本, 'productType = "')).Count -eq 2) "工程 target 数量发生变化"

$目录 = Get-Content -LiteralPath $目录路径 -Raw -Encoding UTF8 | ConvertFrom-Json
$目录键 = @($目录.strings.PSObject.Properties.Name)
$S1目录键 = @($目录键 | Where-Object { $_ -clike "s1.*" })
检查 ($目录.sourceLanguage -ceq "zh-Hans") "String Catalog 源语言不是 zh-Hans"
检查 ($S1目录键.Count -eq 18) "S1 String Catalog 条目应为 18 个，实际为 $($S1目录键.Count) 个"

foreach ($路径 in $保护路径) {
    $基线Blob = @(调用Git @("rev-parse", "${实际基线提交}:$路径"))[0]
    $当前Blob = @(调用Git @("rev-parse", "HEAD:$路径"))[0]
    $工作树Blob = @(调用Git @("hash-object", "--", $路径))[0]
    检查 ($当前Blob -ceq $基线Blob) "当前 HEAD 的受保护 Git blob 已变化：$路径"
    检查 ($工作树Blob -ceq $基线Blob) "工作树的受保护 Git blob 已变化：$路径"
}

$改动路径 = @(
    @(调用Git @("diff", "--name-only", $实际基线提交, "HEAD", "--")) +
    @(调用Git @("diff", "--name-only", "--")) +
    @(调用Git @("diff", "--cached", "--name-only", "--")) +
    @(调用Git @("ls-files", "--others", "--exclude-standard")) |
        Where-Object { $_ } |
        Sort-Object -Unique
)
foreach ($路径 in $改动路径) {
    检查 ($允许改动 -ccontains $路径) "出现范围外改动：$路径"
}
检查 (集合相同 $改动路径 $允许改动) "改动路径集合与本卡八个必要路径不一致"

$依赖路径 = @($改动路径 | Where-Object {
    $_ -cmatch '(^|/)(Package\.swift|Package\.resolved|Podfile|Podfile\.lock|Cartfile|Cartfile\.resolved)$'
})
检查 ($依赖路径.Count -eq 0) "本卡修改了第三方依赖声明"

Push-Location $项目根
try {
    & git diff --check
    $差异格式通过 = $LASTEXITCODE -eq 0
}
finally {
    Pop-Location
}
检查 $差异格式通过 "git diff --check 未通过"

$硬编码脚本 = Join-Path $项目根 "Scripts/scan-hardcoded-user-visible-strings.ps1"
& $硬编码脚本
检查 ($LASTEXITCODE -eq 0) "用户可见硬编码或 String Catalog 双向一致性检查未通过"

$通用自验脚本 = Join-Path $项目根 "Scripts/selfcheck.ps1"
& $通用自验脚本
检查 ($LASTEXITCODE -eq 0) "通用 selfcheck 未通过"

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
    $本地头 = @(调用Git @("rev-parse", "HEAD"))[0]
    $跟踪头 = @(调用Git @("rev-parse", "origin/main"))[0]
    检查 ($本地头 -ceq $跟踪头) "完成态 HEAD 与本地 origin/main 跟踪引用不一致"
}

$报告文本 = Get-Content -LiteralPath $报告路径 -Raw -Encoding UTF8
$报告固定证据 = @(
    "IC-20260814-046-s1-scope-entry-impl",
    $实际基线提交,
    $规格摘要,
    "| 任务给定上游基线 XCTest | $上游测试基线 |",
    "| 实际开发起点 XCTest | $实际起点测试总数 |",
    "| 本卡新增 XCTest | $新增测试总数 |",
    "| 最终 XCTest 总数 | $当前测试总数 |"
)
foreach ($证据 in $报告固定证据) {
    检查 ($报告文本.Contains($证据)) "自验报告缺少固定证据：$证据"
}
foreach ($编号 in @("1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "14b", "14c", "15", "16", "17")) {
    检查 ($报告文本.Contains("| $编号 |")) "报告未逐项列出未定项 $编号"
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
    Write-Host "IC-20260814-046 自验失败：共执行 $检查总数 项检查，失败 $($失败清单.Count) 项。" -ForegroundColor Red
    foreach ($失败项 in $失败清单) {
        Write-Host "  - $失败项" -ForegroundColor Red
    }
    exit 1
}

Write-Host "IC-20260814-046 自验通过：共执行 $检查总数 项检查。" -ForegroundColor Green
if ($允许待回填CI) {
    Write-Host "统计：任务给定上游基线 203；实际起点 208；本卡新增 18；总数 226；运行态待 CI 回填。"
}
else {
    Write-Host "统计：任务给定上游基线 203；实际起点 208；本卡新增 18；总数 226；失败 0；unexpected 0。"
}
Write-Host "保护：范围外 Git blob、导航隔离、改动白名单、硬编码残留与未跟踪条目均符合本卡约束。"
