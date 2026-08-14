param(
    [switch]$允许未提交交付物,
    [switch]$允许待回填CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$工作区 = Split-Path -Parent $项目根
$基线提交 = "f962dc8e81460f897df71e370b465806e830272f"
$S3S4规格摘要 = "BED82109BE905466FEFF2A915D290E7FE98B5179801F6F475995CBED468AD786"
$S1规格摘要 = "F2565629CE6E9BD1ABB7C6841C73460C3E7E8F252A21A70D6E01893B87189238"
$规格清单数量 = 39
$规格清单摘要 = "060383EF4F6BE7D6853FEB1223CB263A3B52463D9F1342ECFA55206004A40B48"
$基线测试总数 = 203
$新增测试总数 = 5
$当前测试总数 = 208
$检查总数 = 0
$失败清单 = [System.Collections.Generic.List[string]]::new()

$S3源码路径 = Join-Path $项目根 "PhotoCleanupMVE/Core/S3StateMachine.swift"
$协调器路径 = Join-Path $项目根 "PhotoCleanupMVE/App/CleanupCoordinator.swift"
$应用入口路径 = Join-Path $项目根 "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"
$测试路径 = Join-Path $项目根 "PhotoCleanupMVETests/S3ReturnRouteTests.swift"
$工程路径 = Join-Path $项目根 "PhotoCleanupMVE.xcodeproj/project.pbxproj"
$追踪路径 = Join-Path $项目根 "Reports/TRACEABILITY-S3-S5.md"
$报告路径 = Join-Path $项目根 "Reports/IC-20260814-045-SELF-VERIFICATION.md"
$S3S4规格路径 = Join-Path $工作区 "SPEC-S3-S4-20260813.v7.md"
$S1规格路径 = Join-Path $工作区 "SPEC-S1-20260813.v3.md"

$允许改动 = @(
    "PhotoCleanupMVE.xcodeproj/project.pbxproj",
    "PhotoCleanupMVE/App/CleanupCoordinator.swift",
    "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift",
    "PhotoCleanupMVE/Core/S3StateMachine.swift",
    "PhotoCleanupMVETests/S3ReturnRouteTests.swift",
    "PhotoCleanupMVETests/TransitionTableGuardTests.swift",
    "Reports/TRACEABILITY-S3-S5.md",
    "Scripts/verify-IC-20260814-045.ps1",
    "Reports/IC-20260814-045-SELF-VERIFICATION.md"
)

$保护路径 = @(
    ".github/workflows/ci.yml",
    "Scripts/selfcheck.ps1",
    "PhotoCleanupMVE/Core/SessionStore.swift",
    "PhotoCleanupMVETests/SessionStoreTests.swift",
    "PhotoCleanupMVE/Services/PhotoLibraryService.swift",
    "PhotoCleanupMVE/Core/S4StateMachine.swift",
    "PhotoCleanupMVE/Core/S5StateMachine.swift",
    "PhotoCleanupMVETests/S3StateMachineTests.swift",
    "PhotoCleanupMVETests/S4StateMachineTests.swift",
    "PhotoCleanupMVETests/S5StateMachineTests.swift"
)

$预期测试方法 = @(
    "testIC045_001ProperSubsetShrinksEveryRangeThroughCoordinator",
    "testIC045_002EmptyReturnClearsSessionSelections",
    "testIC045_003UnchangedReturnPreservesMAndF",
    "testIC045_004MismatchedSourceSessionDoesNotUpdateStore",
    "testIC045_005SharedAssetIsRemovedFromAllRanges"
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

function 计算文本摘要 {
    param([string]$文本)

    $字节 = [Text.UTF8Encoding]::new($false).GetBytes($文本)
    $算法 = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($算法.ComputeHash($字节))).Replace("-", "")
    }
    finally {
        $算法.Dispose()
    }
}

$必需文件 = @(
    $S3源码路径,
    $协调器路径,
    $应用入口路径,
    $测试路径,
    $工程路径,
    $追踪路径,
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

检查 (Test-Path -LiteralPath $S3S4规格路径 -PathType Leaf) "缺少 S3/S4 v7 权威输入"
检查 (Test-Path -LiteralPath $S1规格路径 -PathType Leaf) "缺少 S1 v3 权威输入"
if (Test-Path -LiteralPath $S3S4规格路径 -PathType Leaf) {
    检查 (
        (Get-FileHash -LiteralPath $S3S4规格路径 -Algorithm SHA256).Hash -ceq
            $S3S4规格摘要
    ) "S3/S4 v7 输入摘要不匹配"
}
if (Test-Path -LiteralPath $S1规格路径 -PathType Leaf) {
    检查 (
        (Get-FileHash -LiteralPath $S1规格路径 -Algorithm SHA256).Hash -ceq
            $S1规格摘要
    ) "S1 v3 输入摘要不匹配"
}

$规格文件 = @(
    Get-ChildItem -LiteralPath $工作区 -Filter "SPEC*.md" -File -Recurse |
        Where-Object {
            -not $_.FullName.StartsWith(
                $项目根 + [IO.Path]::DirectorySeparatorChar
            )
        } |
        Sort-Object FullName
)
$规格清单行 = foreach ($文件 in $规格文件) {
    $相对路径 = $文件.FullName.Substring($工作区.Length + 1).Replace("\", "/")
    $摘要 = (Get-FileHash -LiteralPath $文件.FullName -Algorithm SHA256).Hash
    "$相对路径`t$摘要`n"
}
$实际规格清单摘要 = 计算文本摘要 ($规格清单行 -join "")
检查 ($规格文件.Count -eq $规格清单数量) "仓库外 SPEC 文件数量发生变化"
检查 ($实际规格清单摘要 -ceq $规格清单摘要) "仓库外 SPEC 文件内容或路径发生变化"

$历史验证脚本 = @(
    调用Git @("ls-tree", "-r", "--name-only", $基线提交, "--", "Scripts") |
        Where-Object { $_ -cmatch '^Scripts/verify-IC-20260812-[^/]+\.ps1$' }
)
检查 ($历史验证脚本.Count -eq 7) "任务基线的 20260812 历史验证脚本应为 7 个"
$保护路径 += $历史验证脚本
$保护路径 = @($保护路径 | Sort-Object -Unique)
foreach ($路径 in $保护路径) {
    $基线Blob = @(调用Git @("rev-parse", "${基线提交}:$路径"))[0]
    $当前Blob = @(调用Git @("rev-parse", "HEAD:$路径"))[0]
    $工作树Blob = @(调用Git @("hash-object", "--", $路径))[0]
    检查 ($当前Blob -ceq $基线Blob) "当前 HEAD 的受保护 Git blob 已变化：$路径"
    检查 ($工作树Blob -ceq $基线Blob) "工作树的受保护 Git blob 已变化：$路径"
}

$基线S1路径 = @(
    调用Git @(
        "ls-tree",
        "-r",
        "--name-only",
        $基线提交,
        "--",
        "PhotoCleanupMVE/Features/S1"
    )
)
$当前S1路径 = @(
    调用Git @(
        "ls-tree",
        "-r",
        "--name-only",
        "HEAD",
        "--",
        "PhotoCleanupMVE/Features/S1"
    )
)
检查 (集合相同 $当前S1路径 $基线S1路径) "Features/S1 的 Git 路径集合发生变化"
检查 ($当前S1路径.Count -eq 0) "本卡不得接入或新建 S1 文件"

$基线测试行 = @(
    调用Git @(
        "grep",
        "-n",
        "-E",
        "^[[:space:]]*func[[:space:]]+test",
        $基线提交,
        "--",
        "PhotoCleanupMVETests"
    )
)
检查 ($基线测试行.Count -eq $基线测试总数) "基线 XCTest 应为 $基线测试总数 个"

$测试文件 = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $测试路径) -Filter "*.swift" -File
)
$测试匹配 = @(
    Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+(test[A-Za-z0-9_]+)\s*\('
)
$测试方法 = @($测试匹配 | ForEach-Object { $_.Matches[0].Groups[1].Value })
$新增测试匹配 = @(
    Select-String -LiteralPath $测试路径 -Pattern '^\s*func\s+(testIC045_[A-Za-z0-9_]+)\s*\('
)
$新增测试方法 = @(
    $新增测试匹配 | ForEach-Object { $_.Matches[0].Groups[1].Value }
)
检查 ($测试方法.Count -eq $当前测试总数) "当前 XCTest 应为 $当前测试总数 个"
检查 ((@($测试方法 | Sort-Object -Unique)).Count -eq $当前测试总数) "XCTest 方法名存在重复"
检查 ($新增测试方法.Count -eq $新增测试总数) "本卡 XCTest 应为 $新增测试总数 个"
检查 (集合相同 $新增测试方法 $预期测试方法) "本卡 XCTest 方法集合不匹配"

$既有状态机测试计数 = [ordered]@{
    "S3StateMachineTests.swift" = 22
    "S4StateMachineTests.swift" = 45
    "S5StateMachineTests.swift" = 45
}
foreach ($条目 in $既有状态机测试计数.GetEnumerator()) {
    $路径 = Join-Path (Split-Path -Parent $测试路径) $条目.Key
    $数量 = @(
        Select-String -LiteralPath $路径 -Pattern '^\s*func\s+test'
    ).Count
    检查 ($数量 -eq $条目.Value) "$($条目.Key) 测试数应为 $($条目.Value)"
}

$测试文本 = Get-Content -LiteralPath $测试路径 -Raw -Encoding UTF8
检查 (-not $测试文本.Contains("XCTSkip")) "本卡测试不得使用 XCTSkip"
foreach ($编号 in 1..5) {
    $编号文本 = "{0:D3}" -f $编号
    $编号方法 = @(
        $新增测试方法 | Where-Object { $_ -cmatch "^testIC045_${编号文本}" }
    )
    检查 ($编号方法.Count -eq 1) "IC045-$编号文本 应且只能对应一个专项测试"
    检查 ($测试文本.Contains("IC045-$编号文本：")) "缺少 IC045-$编号文本 规格回指注释"
}
$测试关键证据 = @(
    "makeUpstreamReturn()",
    "coordinator.leaveConfirmation()",
    "coordinator.handleS3Return(",
    "pendingDeletionAssetIDsByRangeID",
    "firstMarkedRangeIDByAssetID",
    "allPendingDeletionAssetIDs",
    'sourceSessionID: "其他会话"',
    "范围-月",
    "范围-年",
    "范围-相册"
)
foreach ($证据 in $测试关键证据) {
    检查 ($测试文本.Contains($证据)) "本卡测试缺少关键证据：$证据"
}

$S3源码文本 = Get-Content -LiteralPath $S3源码路径 -Raw -Encoding UTF8
$协调器文本 = Get-Content -LiteralPath $协调器路径 -Raw -Encoding UTF8
$应用入口文本 = Get-Content -LiteralPath $应用入口路径 -Raw -Encoding UTF8
检查 ($S3源码文本.Contains("struct S3UpstreamReturn")) "S3 缺少返回契约值类型"
检查 ($S3源码文本.Contains("let sourceSessionID: String")) "S3 未保存来源整理会话标识"
检查 ($S3源码文本.Contains("currentPendingDeletionAssetIDs: Set<String>")) "S3 返回集合不是唯一集合类型"
检查 ($S3源码文本.Contains("currentPendingDeletionAssetIDs: Set(assetIDs)")) "S3 未在返回瞬间从当前 D 形成集合"
检查 (-not $S3源码文本.Contains("SessionStore")) "S3StateMachine 不得直接依赖或改写 SessionStore"
检查 (-not $S3源码文本.Contains("applyS3Return")) "S3StateMachine 不得直接调用会话层更新"
检查 ($协调器文本.Contains("store.applyS3Return(")) "CleanupCoordinator 未调用 043 的交集更新路径"
检查 ($协调器文本.Contains("func handleS3Return")) "CleanupCoordinator 缺少 S3 返回处理入口"
检查 ($协调器文本.Contains("route = .upstream")) "协调器未选择返回上游落点"
检查 ($协调器文本.Contains("func enterConfirmation")) "协调器未承载会话层进入 S3 的交接"
检查 ($应用入口文本.Contains("case .upstream:")) "应用入口未穷尽新增上游路由"
检查 ($应用入口文本.Contains("EmptyView()")) "新增上游路由没有保持为未接入 S1 的空落点"

$基线协调器文本 = @(调用Git @(
    "show",
    "${基线提交}:PhotoCleanupMVE/App/CleanupCoordinator.swift"
)) -join "`n"
$路由模式 = 'enum CleanupRoute: Equatable \{[\s\S]*?\n\}'
$基线路由 = [regex]::Match($基线协调器文本, $路由模式).Value
$当前路由 = [regex]::Match($协调器文本.Replace("`r`n", "`n"), $路由模式).Value
$当前旧路由 = [regex]::Replace($当前路由, '(?m)^\s*case upstream\n', '')
检查 (-not [string]::IsNullOrEmpty($基线路由)) "无法读取基线 CleanupRoute"
检查 ($当前旧路由 -ceq $基线路由) "既有五个 CleanupRoute 声明发生变化"

$工程文本 = Get-Content -LiteralPath $工程路径 -Raw -Encoding UTF8
检查 (([regex]::Matches($工程文本, "100000000000000000000021")).Count -eq 3) "新增测试文件引用数量不正确"
检查 (([regex]::Matches($工程文本, "20000000000000000000001E")).Count -eq 2) "新增测试未且只未加入一次测试源码阶段"

$追踪文本 = Get-Content -LiteralPath $追踪路径 -Raw -Encoding UTF8
检查 (-not $追踪文本.Contains("SPEC-S3-S4-20260812.v6.md")) "TRACEABILITY 仍指向旧 v6 实现基线"
检查 ($追踪文本.Contains("SPEC-S3-S4-20260813.v7.md")) "TRACEABILITY 未切换到 v7"
检查 ($追踪文本.Contains($S3S4规格摘要)) "TRACEABILITY 缺少 v7 固定摘要"
检查 ($追踪文本.Contains("| 条款总数 | 377 |")) "TRACEABILITY 条款总数未增加 1"
检查 ($追踪文本.Contains("| 已覆盖 | 266 |")) "TRACEABILITY 已覆盖总数未增加 1"
检查 ($追踪文本.Contains("| XCTest 方法总数 | 184 |")) "TRACEABILITY 反向映射测试数未增加 5"
$追踪行 = Get-Content -LiteralPath $追踪路径 -Encoding UTF8
$新增条款行 = @($追踪行 | Where-Object { $_ -cmatch '^C34-231\t' })
检查 ($新增条款行.Count -eq 1) "v7 新增返回条款追踪行应且只能有一行"
if ($新增条款行.Count -eq 1) {
    检查 ($新增条款行[0].Contains("`t29`t")) "v7 新增返回条款行号不是 29"
    foreach ($方法 in $预期测试方法) {
        检查 ($新增条款行[0].Contains($方法)) "v7 新增条款未映射测试：$方法"
    }
}

if (Test-Path -LiteralPath $S3S4规格路径 -PathType Leaf) {
    $规格行 = Get-Content -LiteralPath $S3S4规格路径 -Encoding UTF8
    $S3S4追踪行 = @(
        $追踪行 | Where-Object {
            $_ -cmatch '^C34-[0-9]+\tSPEC-S3-S4-20260813\.v7\.md\t'
        }
    )
    检查 ($S3S4追踪行.Count -eq 231) "S3/S4 正向追踪条款应为 231 行"
    foreach ($行 in $S3S4追踪行) {
        $字段 = $行 -split "`t", 7
        $规格行号 = [int]$字段[2]
        检查 (
            $规格行号 -le $规格行.Count -and
            $规格行[$规格行号 - 1] -ceq $字段[3]
        ) "追踪条款原文或行号与 v7 不一致：$($字段[0])"
    }
}

$改动路径 = @(
    @(
        调用Git @("diff", "--name-only", $基线提交, "HEAD", "--")
    ) +
    @(调用Git @("diff", "--name-only", "--")) +
    @(调用Git @("diff", "--cached", "--name-only", "--")) +
    @(调用Git @("ls-files", "--others", "--exclude-standard")) |
        Where-Object { $_ } |
        Sort-Object -Unique
)
foreach ($路径 in $改动路径) {
    检查 ($允许改动 -ccontains $路径) "出现范围外改动：$路径"
}
检查 (集合相同 $改动路径 $允许改动) "改动路径集合与九个必要交付路径不一致"

$未跟踪路径 = @(调用Git @("ls-files", "--others", "--exclude-standard"))
if ($允许未提交交付物) {
    foreach ($路径 in $未跟踪路径) {
        检查 ($允许改动 -ccontains $路径) "出现非交付物未跟踪条目：$路径"
    }
}
else {
    检查 ($未跟踪路径.Count -eq 0) "完成态仍有未跟踪条目"
    $工作树状态 = @(调用Git @("status", "--porcelain"))
    检查 ($工作树状态.Count -eq 0) "完成态工作树不干净"
    foreach ($路径 in $允许改动) {
        $已追踪 = @(调用Git @("ls-files", "--error-unmatch", "--", $路径))
        检查 ($已追踪.Count -eq 1) "完成态交付路径未被 Git 追踪：$路径"
    }
}

$差异检查 = @(调用Git @("diff", "--check"))
检查 ($差异检查.Count -eq 0) "工作树存在空白错误"
$暂存差异检查 = @(调用Git @("diff", "--cached", "--check"))
检查 ($暂存差异检查.Count -eq 0) "暂存区存在空白错误"

$报告文本 = Get-Content -LiteralPath $报告路径 -Raw -Encoding UTF8
$报告固定证据 = @(
    "IC-20260814-045-contract-alignment-s3-route",
    $基线提交,
    $S3S4规格摘要,
    $S1规格摘要,
    $规格清单摘要,
    "| 基线 XCTest | 203 |",
    "| 新增 XCTest | 5 |",
    "| XCTest 总数 | 208 |"
)
foreach ($证据 in $报告固定证据) {
    检查 ($报告文本.Contains($证据)) "自验报告缺少固定证据：$证据"
}

if ($允许待回填CI) {
    检查 ($报告文本.Contains("CI 结果待本次推送回填")) "CI 前报告缺少待回填标记"
}
else {
    检查 ($报告文本.Contains("全量 XCTest 通过")) "最终报告缺少全量 XCTest 通过证据"
    检查 ($报告文本.Contains("| 失败 | 0 |")) "最终报告缺少 0 失败证据"
    检查 ($报告文本.Contains("| unexpected | 0 |")) "最终报告缺少 0 unexpected 证据"
    检查 ($报告文本.Contains("Release 构建通过")) "最终报告缺少 Release 构建通过证据"
    检查 ($报告文本.Contains("未签名 IPA 产出通过")) "最终报告缺少未签名 IPA 证据"
    检查 ($报告文本 -cmatch '受验提交\s*\|\s*`[0-9a-f]{40}`') "最终报告缺少 CI 受验提交"
    检查 ($报告文本 -cmatch 'CI 运行\s*\|\s*`[^`]+#[0-9]+`') "最终报告缺少 CI 运行编号"
    检查 ($报告文本 -cmatch 'https://github\.com/[^\s)]+/actions/runs/[0-9]+') "最终报告缺少 CI 运行链接"
}

& (Join-Path $PSScriptRoot "selfcheck.ps1")
检查 ($LASTEXITCODE -eq 0) "通用结构自验失败"
& (Join-Path $PSScriptRoot "scan-hardcoded-user-visible-strings.ps1")
检查 ($LASTEXITCODE -eq 0) "用户可见硬编码扫描失败"

$Xcode命令 = Get-Command xcodebuild -ErrorAction SilentlyContinue
if ($null -ne $Xcode命令) {
    & bash (Join-Path $PSScriptRoot "test-xcode.sh")
    检查 ($LASTEXITCODE -eq 0) "全量 XCTest 执行失败"
}
elseif (-not $允许待回填CI) {
    检查 ($报告文本.Contains("全量 XCTest 通过")) "当前无 Xcode，且报告缺少 CI 全量测试证据"
}

if ($失败清单.Count -gt 0) {
    Write-Host "IC-20260814-045 自验失败：共执行 $检查总数 项检查，失败 $($失败清单.Count) 项。" -ForegroundColor Red
    foreach ($失败项 in $失败清单) {
        Write-Host "  - $失败项" -ForegroundColor Red
    }
    exit 1
}

Write-Host "IC-20260814-045 自验通过：共执行 $检查总数 项检查。" -ForegroundColor Green
if ($允许待回填CI) {
    Write-Host "统计：基线 XCTest 203；新增 5；总数 208；运行态失败与 unexpected 待 CI 回填。"
}
else {
    Write-Host "统计：基线 XCTest 203；新增 5；总数 208；失败 0；unexpected 0。"
}
Write-Host "保护：112 项既有状态机测试、SessionStore、范围外文件、全部 SPEC、历史脚本与未跟踪条目均符合本卡约束。"
