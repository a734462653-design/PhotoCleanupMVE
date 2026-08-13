[CmdletBinding()]
param(
    [switch]$允许待回填CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$项目根 = Split-Path -Parent $PSScriptRoot
$工作区 = Split-Path -Parent $项目根
$测试根 = Join-Path $项目根 "PhotoCleanupMVETests"
$测试路径 = Join-Path $测试根 "CoverageGapTests.swift"
$项目路径 = Join-Path $项目根 "PhotoCleanupMVE.xcodeproj/project.pbxproj"
$方案路径 = Join-Path $项目根 "PhotoCleanupMVE.xcodeproj/xcshareddata/xcschemes/PhotoCleanupMVE.xcscheme"
$工作流路径 = Join-Path $项目根 ".github/workflows/ci.yml"
$追踪路径 = Join-Path $项目根 "Reports/TRACEABILITY-S3-S5.md"
$报告路径 = Join-Path $项目根 "Reports/IC-20260812-024-SELF-VERIFICATION.md"
$规格路径 = Join-Path $工作区 "SPEC-S3-S4-20260812.v6.md"
$规格证据路径 = Join-Path $项目根 "Reports/IC-20260812-021-SELF-VERIFICATION.md"
$基线提交 = "5ed266c23cfc657c616fffa54426b904e2824b36"
$基线追踪Blob = "7774caca2f638f86a0b70e4f1e1168aa873544fa"
$规格摘要 = "BF52BBE87692A253BDA9C2AC8B55712C76AB453E3AAF6C5D286BC15835E04C7D"
$预期测试总数 = 189
$预期新增测试数 = 10
$失败清单 = [System.Collections.Generic.List[string]]::new()
$检查总数 = 0

$允许改动 = @(
    ".github/workflows/ci.yml",
    "PhotoCleanupMVETests/CoverageGapTests.swift",
    "Reports/IC-20260812-024-SELF-VERIFICATION.md",
    "Scripts/selfcheck.ps1",
    "Scripts/verify-IC-20260812-024.ps1"
)

$预期方法 = @(
    "testC34_093GeneratedSubmissionIdentifiersAreUnique",
    "testC34_093SubmissionIdentifierEndsWhenTargetS5Receives",
    "testC34_094AssetIdentifiersEndWhenTargetS5Receives",
    "testC34_095AssetCountEndsWhenTargetS5Receives",
    "testC34_096KnownTotalBytesEndsWhenTargetS5Receives",
    "testC34_097UnavailableCountEndsWhenTargetS5Receives",
    "testC34_098VolumeDisplayModeEndsWhenTargetS5Receives",
    "testC34_099FavoriteAssetIdentifiersEndWhenTargetS5Receives",
    "testC34_100FrozenTimeEndsWhenTargetS5Receives",
    "testC34_101TwoFirstFreezeGuardsDefineCurrentCompletenessBoundary"
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
    $测试路径,
    $项目路径,
    $方案路径,
    $工作流路径,
    $追踪路径,
    $报告路径,
    $规格证据路径,
    (Join-Path $PSScriptRoot "selfcheck.ps1")
)
foreach ($路径 in $必需文件) {
    检查 (Test-Path -LiteralPath $路径 -PathType Leaf) "缺少必需文件：$路径"
}

& (Join-Path $PSScriptRoot "selfcheck.ps1")
检查 ($LASTEXITCODE -eq 0) "通用结构自验未通过"

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

$基线测试行 = @(调用Git @(
    "grep",
    "-n",
    "-E",
    "^[[:space:]]*func[[:space:]]+test",
    $基线提交,
    "--",
    "PhotoCleanupMVETests"
))
检查 ($基线测试行.Count -eq 179) "任务基线 XCTest 应为 179 个，实际为 $($基线测试行.Count) 个"

$测试文件 = @(Get-ChildItem -LiteralPath $测试根 -Filter "*.swift" -File)
$测试匹配 = @(
    Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+(test[A-Za-z0-9_]+)\s*\('
)
$测试方法 = @($测试匹配 | ForEach-Object { $_.Matches[0].Groups[1].Value })
检查 ($测试方法.Count -eq $预期测试总数) "XCTest 方法应为 $预期测试总数 个，实际为 $($测试方法.Count) 个"
检查 ((@($测试方法 | Sort-Object -Unique)).Count -eq $预期测试总数) "XCTest 方法名存在重复"
检查 (($测试方法.Count - $基线测试行.Count) -eq $预期新增测试数) "新增 XCTest 应为 $预期新增测试数 个"

foreach ($方法 in $预期方法) {
    检查 ($测试方法 -ccontains $方法) "缺少专项 XCTest：$方法"
}
foreach ($编号 in 93..101) {
    $编号文本 = "{0:D3}" -f $编号
    $命中 = @($测试方法 | Where-Object { $_ -cmatch "^testC34_${编号文本}" })
    $预期命中数 = if ($编号 -eq 93) { 2 } else { 1 }
    检查 ($命中.Count -eq $预期命中数) "C34-$编号文本 的专项方法数应为 $预期命中数，实际为 $($命中.Count)"
}

$测试文本 = Get-Content -LiteralPath $测试路径 -Raw -Encoding UTF8
检查 (-not $测试文本.Contains("XCTSkip")) "专项测试不得用 XCTSkip 表面跳过失败"
检查 ($测试文本.Contains("let sampleCount = 256")) "C34-093 缺少 256 次默认生成样本"
检查 ($测试文本.Contains("UUID(uuidString: snapshot.submissionID)")) "C34-093 缺少 UUID 生成格式断言"
检查 ($测试文本.Contains("generatedIdentifiers.insert(snapshot.submissionID).inserted")) "C34-093 缺少生成值唯一插入断言"
检查 ($测试文本.Contains(".rejected(.invalidState(.empty))")) "C34-101 缺少非空守卫拒绝断言"
检查 ($测试文本.Contains(".rejected(.invalidState(.scanning))")) "C34-101 缺少扫描完成守卫拒绝断言"
检查 ($测试文本.Contains("guard case .frozen = machine.freezeSubmissionSnapshot()")) "C34-101 缺少通过两条守卫后的接受断言"

$产品路径 = @(调用Git @("ls-tree", "-r", "--name-only", $基线提交, "--", "PhotoCleanupMVE"))
$当前产品路径 = @(调用Git @("ls-tree", "-r", "--name-only", "HEAD", "--", "PhotoCleanupMVE"))
检查 ($产品路径.Count -gt 0) "任务基线没有产品源码"
检查 (集合相同 $产品路径 $当前产品路径) "产品路径集合相对任务基线发生变化"
foreach ($路径 in $产品路径) {
    $基线Blob = @(调用Git @("rev-parse", "${基线提交}:$路径"))[0]
    $当前Blob = @(调用Git @("rev-parse", "HEAD:$路径"))[0]
    检查 ($当前Blob -ceq $基线Blob) "当前 HEAD 的产品 Git blob 已变化：$路径"

    $工作树Blob = @(调用Git @("hash-object", "--", $路径))[0]
    检查 ($工作树Blob -ceq $基线Blob) "工作树的产品 Git blob 已变化：$路径"
}
$未跟踪产品 = @(调用Git @("ls-files", "--others", "--exclude-standard", "--", "PhotoCleanupMVE"))
检查 ($未跟踪产品.Count -eq 0) "产品目录出现未跟踪文件"

$当前追踪Blob = @(调用Git @("rev-parse", "HEAD:Reports/TRACEABILITY-S3-S5.md"))[0]
$工作树追踪Blob = @(调用Git @("hash-object", "--", "Reports/TRACEABILITY-S3-S5.md"))[0]
检查 ($当前追踪Blob -ceq $基线追踪Blob) "当前 HEAD 的追踪矩阵 Git blob 已变化"
检查 ($工作树追踪Blob -ceq $基线追踪Blob) "工作树的追踪矩阵 Git blob 已变化"
if (Test-Path -LiteralPath $规格路径 -PathType Leaf) {
    $实际规格摘要 = (Get-FileHash -LiteralPath $规格路径 -Algorithm SHA256).Hash
    检查 ($实际规格摘要 -ceq $规格摘要) "输入 SPEC 摘要已变化"
}
else {
    $规格证据文本 = Get-Content -LiteralPath $规格证据路径 -Raw -Encoding UTF8
    检查 (
        $规格证据文本.Contains("SPEC-S3-S4-20260812.v6.md") -and
        $规格证据文本.Contains($规格摘要)
    ) "CI 缺少仓库外 SPEC，且 IC-021 报告没有固定摘要证据"
}

$项目文本 = Get-Content -LiteralPath $项目路径 -Raw -Encoding UTF8
$方案文本 = Get-Content -LiteralPath $方案路径 -Raw -Encoding UTF8
$产品类型 = @(
    [regex]::Matches($项目文本, 'productType = "([^"]+)";') |
        ForEach-Object { $_.Groups[1].Value }
)
$允许产品类型 = @(
    "com.apple.product-type.application",
    "com.apple.product-type.bundle.unit-test"
)
检查 ($产品类型.Count -eq 2) "工程 target 数量应为 2，实际为 $($产品类型.Count)"
检查 (集合相同 $产品类型 $允许产品类型) "工程 target 类型不是应用加单元测试"
检查 (-not $项目文本.Contains("com.apple.product-type.bundle.ui-testing")) "工程出现 XCUITest 产品类型"
检查 (-not $项目文本.Contains("XCUITest")) "工程文件出现 XCUITest target"
检查 (-not $方案文本.Contains("UITest")) "共享方案出现 UI 测试引用"

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
$测试改动 = @($改动路径 | Where-Object { $_.StartsWith("PhotoCleanupMVETests/") })
检查 (集合相同 $测试改动 @("PhotoCleanupMVETests/CoverageGapTests.swift")) "测试改动必须且只能位于 CoverageGapTests.swift"
检查 (-not ($改动路径 -ccontains "PhotoCleanupMVE.xcodeproj/project.pbxproj")) "不得修改工程 target 配置"
检查 (-not ($改动路径 -ccontains "Reports/TRACEABILITY-S3-S5.md")) "不得修改追踪矩阵"

$工作流文本 = Get-Content -LiteralPath $工作流路径 -Raw -Encoding UTF8
检查 ($工作流文本.Contains("run: ./Scripts/verify-IC-20260812-024.ps1 -允许待回填CI")) "CI 未调用本卡专项自验"
检查 ($工作流文本.Contains("run: bash Scripts/test-xcode.sh")) "CI 未运行全量 XCTest"

$报告文本 = Get-Content -LiteralPath $报告路径 -Raw -Encoding UTF8
检查 ($报告文本.Contains("IC-20260812-024")) "自验报告缺少任务编号"
检查 ($报告文本.Contains("| 新增 XCTest | 10 |")) "自验报告新增测试数不匹配"
检查 ($报告文本.Contains("| XCTest 总数 | 189 |")) "自验报告测试总数不匹配"
检查 ($报告文本.Contains("| 阻塞清单 | 无 |")) "自验报告阻塞清单不匹配"
检查 ($报告文本.Contains("C34-101")) "自验报告缺少 C34-101 完备性边界说明"
检查 ($报告文本.Contains("重复冻结")) "自验报告未说明 C34-101 排除的重复冻结守卫"
检查 ($报告文本.Contains("本报告自身为末次提交")) "自验报告未注明末次提交关系"

if ($允许待回填CI) {
    检查 ($报告文本.Contains("CI 结果待本次推送回填")) "CI 阶段报告缺少待回填标记"
}
else {
    检查 ($报告文本 -cmatch 'CI 编号\s*\|\s*`iOS 构建与自验 #\d+`') "最终报告缺少 CI 编号"
    检查 ($报告文本 -cmatch 'https://github\.com/a734462653-design/PhotoCleanupMVE/actions/runs/\d+') "最终报告缺少 CI 运行链接"
    检查 ($报告文本 -cmatch '受验提交\s*\|\s*`[0-9a-f]{40}`') "最终报告缺少 CI 受验提交哈希"
}

if ($失败清单.Count -gt 0) {
    Write-Host "IC-20260812-024 自验失败：共执行 $检查总数 项检查，失败 $($失败清单.Count) 项。" -ForegroundColor Red
    foreach ($失败项 in $失败清单) {
        Write-Host "  - $失败项" -ForegroundColor Red
    }
    exit 1
}

Write-Host "IC-20260812-024 自验通过：共执行 $检查总数 项检查。" -ForegroundColor Green
Write-Host "统计：新增 XCTest 10；总数 189；C34-093 两项，C34-094 至 C34-101 各一项；阻塞清单为空。"
Write-Host "保护：产品源码 Git blob、SPEC 与追踪矩阵均未变化；工程只有应用与单元测试两个 target。"
