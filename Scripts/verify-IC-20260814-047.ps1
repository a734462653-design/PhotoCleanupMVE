param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$项目根 = Split-Path -Parent $PSScriptRoot
$工作区 = Split-Path -Parent $项目根
$基线提交 = "480ef52b7c9fb4bf34077d00f2ff2f4edad923e4"
$规格摘要 = "25741959F965B8D9438F7265745D70EE60339A6865E1763BDE71912782BED1D8"
$基线测试总数 = 226
$新增测试总数 = 41
$当前测试总数 = 267
$检查总数 = 0
$失败清单 = [System.Collections.Generic.List[string]]::new()

$状态机路径 = Join-Path $项目根 "PhotoCleanupMVE/Core/S2StateMachine.swift"
$视图路径 = Join-Path $项目根 "PhotoCleanupMVE/Features/S2/S2View.swift"
$测试路径 = Join-Path $项目根 "PhotoCleanupMVETests/S2StateMachineTests.swift"
$目录路径 = Join-Path $项目根 "PhotoCleanupMVE/Localizable.xcstrings"
$权限路径 = Join-Path $项目根 "PhotoCleanupMVE/Info.plist"
$工程路径 = Join-Path $项目根 "PhotoCleanupMVE.xcodeproj/project.pbxproj"
$工作流路径 = Join-Path $项目根 ".github/workflows/ci.yml"
$报告路径 = Join-Path $项目根 "Reports/IC-20260814-047-SELF-VERIFICATION.md"
$规格路径 = Join-Path $工作区 "SPEC-S2-20260813.v13.md"
$来源视口路径 = Join-Path $工作区 "PhotoCleanupGestureDemo/S2GestureCalibration/GestureViewport.swift"
$来源模型路径 = Join-Path $工作区 "PhotoCleanupGestureDemo/S2GestureCalibration/CalibrationModel.swift"

$允许改动 = @(
    ".github/workflows/ci.yml",
    "PhotoCleanupMVE.xcodeproj/project.pbxproj",
    "PhotoCleanupMVE/Core/S2StateMachine.swift",
    "PhotoCleanupMVE/Features/S2/S2View.swift",
    "PhotoCleanupMVE/Info.plist",
    "PhotoCleanupMVE/Localizable.xcstrings",
    "PhotoCleanupMVETests/S2StateMachineTests.swift",
    "Reports/IC-20260814-047-SELF-VERIFICATION.md",
    "Scripts/verify-IC-20260814-047.ps1"
)

$保护Blob = [ordered]@{
    "PhotoCleanupMVE/Core/SessionStore.swift" = "17d36192898a3d584df37a7e3efaf9c088045789"
    "PhotoCleanupMVE/Core/S1StateMachine.swift" = "2128c759f78ce69c4086cef11d4c88e800c08a24"
    "PhotoCleanupMVE/Core/S3StateMachine.swift" = "dc85e9941b1e4d37b5b55d8dadd4c6d4732e98bc"
    "PhotoCleanupMVE/Core/S4StateMachine.swift" = "38508e188d8efb022c2ec9082602e5358d9cd544"
    "PhotoCleanupMVE/Core/S5StateMachine.swift" = "4683c137b912bc1b2bc01f0fd19238d0bf091059"
    "PhotoCleanupMVETests/SessionStoreTests.swift" = "7bb23d64b61a5c4b962d182f45cb26732126f571"
    "PhotoCleanupMVETests/S1StateMachineTests.swift" = "353db5ff045a374cf456c87d3b47de2b2c2c5155"
    "PhotoCleanupMVETests/S3StateMachineTests.swift" = "091358b6a1d198b0fec4c3709db49694cef7b3ef"
    "PhotoCleanupMVETests/S4StateMachineTests.swift" = "54740d5a74a9f958ac2534e188e1da763e7034a6"
    "PhotoCleanupMVETests/S5StateMachineTests.swift" = "08916b1869dc920a02fda63543ae86a78a03d834"
    "PhotoCleanupMVE/App/CleanupCoordinator.swift" = "4256b4d3cef06ced2c0dcf8de5bc27b1ae039bb6"
}

$预期测试方法 = @(
    "testIC047_001AllSixStatesAreReachable",
    "testIC047_002TransitionRowEnterFromS1",
    "testIC047_003TransitionRowSingleTap",
    "testIC047_004TransitionRowDoubleTap",
    "testIC047_005TransitionRowPinch",
    "testIC047_006TransitionRowSwipeUp",
    "testIC047_007TransitionRowSwipeDown",
    "testIC047_008TransitionRowHorizontalSwipe",
    "testIC047_009TransitionRowMainDragWithoutPaging",
    "testIC047_010TransitionRowBeginBottomStripDrag",
    "testIC047_011TransitionRowChangePhotoDuringBottomStripDrag",
    "testIC047_012TransitionRowEndBottomStripDrag",
    "testIC047_013TransitionRowFavorite",
    "testIC047_014TransitionRowRecentAlbum",
    "testIC047_015TransitionRowTapAddAlbum",
    "testIC047_016TransitionRowUnderlyingInputWhileSheetPresented",
    "testIC047_017TransitionRowAlbumSheetSuccess",
    "testIC047_018TransitionRowAlbumSheetFailure",
    "testIC047_019TransitionRowCancelAlbumSheet",
    "testIC047_020TransitionRowBack",
    "testIC047_021TransitionRowConfirmation",
    "testIC047_022TransitionRowSystemEdgeSwipeBack",
    "testIC047_023GestureMatrixSingleTapRow",
    "testIC047_024GestureMatrixDoubleTapRow",
    "testIC047_025GestureMatrixPinchRow",
    "testIC047_026GestureMatrixSwipeUpRow",
    "testIC047_027GestureMatrixSwipeDownRow",
    "testIC047_028GestureMatrixHorizontalSwipeRow",
    "testIC047_029GestureMatrixMainDragRow",
    "testIC047_030GestureMatrixBottomStripDragRow",
    "testIC047_031GestureMatrixUnderlyingControlRow",
    "testIC047_032GestureMatrixSheetControlRow",
    "testIC047_033GestureMatrixSystemEdgeSwipeRow",
    "testIC047_034GestureMatrixUndefinedGestureRow",
    "testIC047_035PinchExclusivelyOwnsTouchSequence",
    "testIC047_036PinchHardClampSnapBackAndVisibilityPreservation",
    "testIC047_037DoubleTapEnterAndExitRestoresVisibility",
    "testIC047_038EveryPagingPathResetsScaleToOne",
    "testIC047_039NxVerticalMarkingSemanticsAreDisabled",
    "testIC047_040NxSingleTapDoesNothing",
    "testIC047_041MigratedGeometryFunctionsKeepVerifiedFormulas"
)

$迁移事件 = @(
    "enterFromS1",
    "singleTapMainImage",
    "doubleTapMainImage",
    "pinchMainImage",
    "swipeUpMainImage",
    "swipeDownMainImage",
    "horizontalSwipeMainImage",
    "dragMainImageWithoutPaging",
    "beginBottomStripDrag",
    "changeCurrentPhotoDuringBottomStripDrag",
    "endBottomStripDrag",
    "tapFavorite",
    "tapRecentAlbum",
    "tapAddAlbum",
    "operateUnderlyingS2WhileSheetPresented",
    "selectAlbumAndWriteSucceeds",
    "selectAlbumAndWriteFails",
    "cancelAlbumSheet",
    "tapBack",
    "tapConfirmation",
    "systemEdgeSwipeBack"
)

$手势输入 = @(
    "singleTapMainImage",
    "doubleTapMainImage",
    "pinchMainImage",
    "swipeUpMainImage",
    "swipeDownMainImage",
    "horizontalSwipeMainImage",
    "dragMainImage",
    "dragBottomStrip",
    "tapUnderlyingControl",
    "tapSheetControl",
    "systemEdgeSwipe",
    "undefinedMainImageGesture"
)

$未定项声明 = @(
    "item01InitialPresentation",
    "item02LastAssetMarkOutcome",
    "item03SequenceBoundaryFeedback",
    "item04aPinchMaxScale",
    "item04bZoomSnapBackThreshold",
    "item04cAspectFillDegeneration",
    "item04dDoubleTapAnchorStrategy",
    "item04eEdgePagingThresholds",
    "item05GestureRecognition",
    "item06BottomStripMetrics",
    "item07CopyLayoutAndStyle",
    "item08AssetLoadingAndRecovery",
    "item08ScaleChangeRequestPolicy",
    "item08DegradedPreviewPolicy",
    "item09EmptyPendingPresentation",
    "item10SnapshotPersistence",
    "item11WriteFailureFeedback",
    "item12AlbumRemovalHint",
    "item13AlbumHistoryDepth",
    "item14AlbumHistoryPersistence",
    "item15InFlightControls",
    "item16AlreadyContainedCopy",
    "item17AlbumBadgePresentation",
    "item18BottomStripMarkPresentation",
    "item19AlreadyMarkedHint"
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
    $测试路径,
    $目录路径,
    $权限路径,
    $工程路径,
    $工作流路径,
    $报告路径,
    $PSCommandPath
)
foreach ($路径 in $必需文件) {
    检查 (Test-Path -LiteralPath $路径 -PathType Leaf) "缺少必需文件：$路径"
}

$当前头 = @(调用Git @("rev-parse", "HEAD"))[0]
检查 ($当前头 -ceq $基线提交) "本卡未提交模式下 HEAD 必须保持任务基线"

if (Test-Path -LiteralPath $规格路径 -PathType Leaf) {
    $实际摘要 = (Get-FileHash -LiteralPath $规格路径 -Algorithm SHA256).Hash
    检查 ($实际摘要 -ceq $规格摘要) "SPEC-S2 v13 摘要与任务卡不一致"
}
else {
    检查 $false "缺少仓库外只读输入 SPEC-S2-20260813.v13.md"
}

$来源摘要 = [ordered]@{
    $来源视口路径 = "E49B74D50CC1119CAE340BC7666E44904D19E95491291D607DB5A52853874379"
    $来源模型路径 = "DD179BE2D81C68437F21C2C42B467CF31C83271962D88FF95DB56A0A836F7BB8"
}
foreach ($路径 in $来源摘要.Keys) {
    if (Test-Path -LiteralPath $路径 -PathType Leaf) {
        $实际摘要 = (Get-FileHash -LiteralPath $路径 -Algorithm SHA256).Hash
        检查 ($实际摘要 -ceq $来源摘要[$路径]) "只读 Demo 来源文件发生变化：$路径"
    }
    else {
        检查 $false "缺少只读 Demo 来源文件：$路径"
    }
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
$测试匹配 = @(Select-String -LiteralPath $测试文件.FullName -Pattern '^\s*func\s+(test[A-Za-z0-9_]+)\s*\(')
$测试方法 = @($测试匹配 | ForEach-Object { $_.Matches[0].Groups[1].Value })
$新增匹配 = @(Select-String -LiteralPath $测试路径 -Pattern '^\s*func\s+(testIC047_[A-Za-z0-9_]+)\s*\(')
$新增方法 = @($新增匹配 | ForEach-Object { $_.Matches[0].Groups[1].Value })
检查 ($测试方法.Count -eq $当前测试总数) "当前 XCTest 应为 $当前测试总数 个，实际为 $($测试方法.Count) 个"
检查 ((@($测试方法 | Sort-Object -Unique)).Count -eq $当前测试总数) "XCTest 方法名存在重复"
检查 ($新增方法.Count -eq $新增测试总数) "本卡新增 XCTest 应为 $新增测试总数 个，实际为 $($新增方法.Count) 个"
检查 (集合相同 $新增方法 $预期测试方法) "本卡编号 XCTest 方法集合不匹配"

$测试文本 = Get-Content -LiteralPath $测试路径 -Raw -Encoding UTF8
检查 (-not $测试文本.Contains("XCTSkip")) "本卡测试不得使用 XCTSkip"
foreach ($编号 in 1..$新增测试总数) {
    $编号文本 = "{0:D3}" -f $编号
    检查 ($测试文本.Contains("IC047-$编号文本：")) "测试缺少 IC047-$编号文本 的中文回指注释"
}

$状态机文本 = Get-Content -LiteralPath $状态机路径 -Raw -Encoding UTF8
foreach ($状态编号 in 1..6) {
    检查 ($状态机文本.Contains("`"S2-$状态编号`"")) "状态机缺少 S2-$状态编号"
}
foreach ($事件 in $迁移事件) {
    $事件声明数 = ([regex]::Matches(
        $状态机文本,
        "(?m)^\s*case\s+$事件\s*$"
    )).Count
    检查 ($事件声明数 -ge 1) "迁移表缺少事件声明：$事件"
}
检查 ($迁移事件.Count -eq 21) "第四节迁移事件行静态清单不是 21 行"
foreach ($输入 in $手势输入) {
    $输入声明数 = ([regex]::Matches(
        $状态机文本,
        "(?m)^\s*case\s+$输入\s*$"
    )).Count
    检查 ($输入声明数 -ge 1) "手势矩阵缺少输入声明：$输入"
}
检查 ($手势输入.Count * 3 -eq 36) "第五节手势矩阵静态单元格不是 36 格"

foreach ($声明 in $未定项声明) {
    $声明数 = ([regex]::Matches(
        $状态机文本,
        "static let $声明\s*=\s*S2UndecidedPlaceholder\.unresolved"
    )).Count
    检查 ($声明数 -eq 1) "未定项占位未且只未集中声明一次：$声明"
}
检查 ($状态机文本.Contains("let imageRequestStrategy: S2ImageRequestStrategy?")) "图像请求策略没有保持可空占位"
检查 ($状态机文本.Contains("item08ScaleChangeRequestPolicy")) "未定项 8 缺少 s 变化请求策略占位"
检查 ($状态机文本.Contains("item08DegradedPreviewPolicy")) "未定项 8 缺少降质预览策略占位"

foreach ($来源任务 in @(
    "IC-20260812-007-s2-gesture-calibration",
    "IC-20260812-022-demo-aspect-fill-zoom",
    "IC-20260813-033"
)) {
    检查 ($状态机文本.Contains($来源任务)) "几何函数注释缺少来源任务号：$来源任务"
}
foreach ($函数名 in @(
    "aspectFitSize",
    "aspectFillMultiplier",
    "doubleTapAnchorOffset",
    "panLimits",
    "clampedOffset"
)) {
    检查 ($状态机文本.Contains("static func $函数名")) "缺少移植几何函数：$函数名"
}
检查 (-not $状态机文本.Contains("panBoundaryAllowance")) "panLimits 仍保留可调余量参数"
检查 (-not $状态机文本.Contains("let allowance")) "panLimits 仍计算非零余量"
检查 ($状态机文本.Contains("max(1, pinchStartScale * magnification)")) "捏合下限没有硬钳在 1"
检查 ($状态机文本.Contains("scale < parameters.zoomSnapBackThreshold")) "捏合结束缺少严格小于阈值的吸附归位"
检查 ($状态机文本.Contains("touchSequenceOwner = .pinch")) "捏合没有取得触摸序列所有权"
检查 ($状态机文本.Contains("visibilityBeforeDoubleTapZoom")) "双击显隐恢复记录缺失"
检查 ($状态机文本.Contains("resetZoomAfterPhotoChange")) "翻页重置缩放链路缺失"

$视图文本 = Get-Content -LiteralPath $视图路径 -Raw -Encoding UTF8
检查 (([regex]::Matches($视图文本, '#Preview\("S2-[1-6]"\)')).Count -eq 6) "S2 六状态独立预览数量不正确"
检查 ($视图文本.Contains("MagnifyGesture(")) "S2View 缺少双指捏合手势"
检查 ($视图文本.Contains(".exclusively(before:")) "S2View 未把捏合放入独占手势组合"
检查 ($视图文本.Contains("struct S2BottomStripView")) "缺少底部横栏视图"
检查 ($视图文本.Contains("changeCurrentPhotoDuringBottomStripDrag")) "横栏拖动未同步切换主图"
检查 (-not $视图文本.Contains("ParameterPanel")) "S2View 意外引入调参面板"

$产品Swift = @(
    Get-ChildItem -LiteralPath (Join-Path $项目根 "PhotoCleanupMVE") -Filter "*.swift" -File -Recurse
)
$其他产品Swift = @($产品Swift | Where-Object { $_.FullName -cne $视图路径 })
$视图外引用 = @(Select-String -LiteralPath $其他产品Swift.FullName -SimpleMatch -Pattern "S2View")
检查 ($视图外引用.Count -eq 0) "S2View 被自身预览之外的产品源码或导航引用"

$动画模式 = '\bwithAnimation\b|\.animation\s*\(|\.transition\s*\(|matchedGeometryEffect|UIView\.animate|CAAnimation|Animation\.'
$动画命中 = @(Select-String -LiteralPath $产品Swift.FullName -Pattern $动画模式)
检查 ($动画命中.Count -eq 0) "产品源码出现动画 API，命中数：$($动画命中.Count)"

$图像请求命中 = @(Select-String -LiteralPath @($状态机路径, $视图路径) -Pattern 'PHImageManager|requestImage\s*\(|PHImageRequestOptions')
检查 ($图像请求命中.Count -eq 0) "S2 在未定项 8 决议前实现了具体图像请求策略"

$工程文本 = Get-Content -LiteralPath $工程路径 -Raw -Encoding UTF8
foreach ($文件名 in @("S2StateMachine.swift", "S2View.swift", "S2StateMachineTests.swift")) {
    检查 ($工程文本.Contains($文件名)) "工程未引用新增文件：$文件名"
}
检查 (([regex]::Matches($工程文本, 'productType = "')).Count -eq 2) "工程 target 数量发生变化"

$目录 = Get-Content -LiteralPath $目录路径 -Raw -Encoding UTF8 | ConvertFrom-Json
$目录键 = @($目录.strings.PSObject.Properties.Name)
$S2目录键 = @($目录键 | Where-Object { $_ -clike "s2.*" })
检查 ($目录.sourceLanguage -ceq "zh-Hans") "String Catalog 源语言不是 zh-Hans"
检查 ($S2目录键.Count -eq 19) "S2 String Catalog 条目应为 19 个，实际为 $($S2目录键.Count) 个"

[xml]$权限文档 = Get-Content -LiteralPath $权限路径 -Raw -Encoding UTF8
$权限节点 = @($权限文档.SelectSingleNode("/plist/dict").ChildNodes)
$权限文案 = $null
for ($索引 = 0; $索引 -lt $权限节点.Count - 1; $索引++) {
    if ($权限节点[$索引].Name -eq "key" -and
        $权限节点[$索引].InnerText -eq "NSPhotoLibraryUsageDescription") {
        $权限文案 = $权限节点[$索引 + 1].InnerText
        break
    }
}
检查 ($null -ne $权限文案 -and $权限文案.Contains("删除")) "照片库权限文案没有覆盖删除用途"
检查 ($null -ne $权限文案 -and -not $权限文案.Contains("不会修改照片库")) "照片库权限文案仍沿用 Demo 的不修改表述"

$当前工作流 = Get-Content -LiteralPath $工作流路径 -Raw -Encoding UTF8
$基线工作流 = (@(调用Git @("show", "${基线提交}:.github/workflows/ci.yml")) -join "`n").TrimEnd()
$还原工作流 = ($当前工作流 -replace 'timeout-minutes:\s*15', 'timeout-minutes: 45')
$还原工作流 = ($还原工作流 -replace "`r`n", "`n").TrimEnd()
检查 (([regex]::Matches($当前工作流, 'timeout-minutes:\s*15')).Count -eq 1) "CI timeout-minutes 不是唯一的 15"
检查 ($还原工作流 -ceq $基线工作流) "ci.yml 除 timeout-minutes 外还发生了变化"
检查 ($当前工作流 -cmatch '(?m)^on:\r?\n  push:\r?\n  workflow_dispatch:') "CI push 触发结构发生变化"

foreach ($条目 in $保护Blob.GetEnumerator()) {
    $路径 = [string]$条目.Key
    $预期Blob = [string]$条目.Value
    $头Blob = @(调用Git @("rev-parse", "HEAD:$路径"))[0]
    $工作树Blob = @(调用Git @("hash-object", "--", $路径))[0]
    检查 ($头Blob -ceq $预期Blob) "HEAD 的受保护 Git blob 不符合任务基线：$路径"
    检查 ($工作树Blob -ceq $预期Blob) "工作树的受保护 Git blob 已变化：$路径"
}

$改动路径 = @(
    @(调用Git @("diff", "--name-only", $基线提交, "--")) +
    @(调用Git @("ls-files", "--others", "--exclude-standard")) |
        Where-Object { $_ } |
        Sort-Object -Unique
)
检查 (集合相同 $改动路径 $允许改动) "改动路径集合与本卡九个交付路径不一致"
foreach ($路径 in $改动路径) {
    检查 ($允许改动 -ccontains $路径) "出现范围外改动：$路径"
}

$未跟踪路径 = @(调用Git @("ls-files", "--others", "--exclude-standard"))
检查 ($未跟踪路径.Count -eq 0) "本卡仍有未跟踪条目"
foreach ($路径 in $允许改动) {
    $已追踪 = @(调用Git @("ls-files", "--error-unmatch", "--", $路径))
    检查 ($已追踪.Count -eq 1) "交付路径未被 Git 索引追踪：$路径"
}

Push-Location $项目根
try {
    & git diff --check $基线提交
    $差异格式通过 = $LASTEXITCODE -eq 0
}
finally {
    Pop-Location
}
检查 $差异格式通过 "git diff --check 未通过"

& (Join-Path $PSScriptRoot "scan-hardcoded-user-visible-strings.ps1")
检查 ($LASTEXITCODE -eq 0) "用户可见硬编码或 String Catalog 双向一致性检查未通过"
& (Join-Path $PSScriptRoot "selfcheck.ps1")
检查 ($LASTEXITCODE -eq 0) "通用结构自验未通过"

$报告文本 = Get-Content -LiteralPath $报告路径 -Raw -Encoding UTF8
foreach ($证据 in @(
    "IC-20260814-047-s2-viewer-impl",
    $基线提交,
    $规格摘要,
    "| 基线 XCTest | $基线测试总数 |",
    "| 新增 XCTest | $新增测试总数 |",
    "| 静态 XCTest 总数 | $当前测试总数 |",
    "CI 未触发",
    "未提交、未推送"
)) {
    检查 ($报告文本.Contains($证据)) "自验报告缺少固定证据：$证据"
}
foreach ($编号 in 1..19) {
    检查 ($报告文本.Contains("| $编号 |")) "报告未逐项对应 v13 第九节未定项 $编号"
}

if ($失败清单.Count -gt 0) {
    Write-Host "IC-20260814-047 自验失败：共执行 $检查总数 项检查，失败 $($失败清单.Count) 项。" -ForegroundColor Red
    foreach ($失败项 in $失败清单) {
        Write-Host "  - $失败项" -ForegroundColor Red
    }
    exit 1
}

Write-Host "IC-20260814-047 自验通过：共执行 $检查总数 项检查。" -ForegroundColor Green
Write-Host "统计：基线 XCTest 226；新增 41；静态总数 267。"
Write-Host "保护：范围外 Git blob、动画零命中、零导航接线、String Catalog 双向一致与零未跟踪条目均通过。"
Write-Host "执行边界：遵照完成后动作，未触发 CI；当前 Windows 主机无 Xcode。"
exit 0
