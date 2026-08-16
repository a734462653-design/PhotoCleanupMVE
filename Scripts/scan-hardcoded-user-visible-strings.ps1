param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$catalogPath = Join-Path $projectRoot "PhotoCleanupMVE/Localizable.xcstrings"
$sourceRoot = Join-Path $projectRoot "PhotoCleanupMVE"
$failures = [System.Collections.Generic.List[string]]::new()
$residuals = [System.Collections.Generic.List[object]]::new()
$diagnostics = [System.Collections.Generic.List[object]]::new()
$specExemptions = [System.Collections.Generic.List[object]]::new()
$residualIndex = @{}
$catalog = $null

function Add-Residual {
    param(
        [string]$Path,
        [int]$LineNumber,
        [string]$Value,
        [string]$Reason
    )

    $identity = "$Path`:$LineNumber`:$Value`:$Reason"
    if (-not $residualIndex.ContainsKey($identity)) {
        $residualIndex[$identity] = $true
        $residuals.Add([PSCustomObject]@{
            Path = $Path
            LineNumber = $LineNumber
            Value = $Value
            Reason = $Reason
        })
    }
}

if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    $failures.Add("缺少 String Catalog：PhotoCleanupMVE/Localizable.xcstrings")
}

$catalogKeys = @()
if ($failures.Count -eq 0) {
    try {
        $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 |
            ConvertFrom-Json
    }
    catch {
        $failures.Add("Localizable.xcstrings 不是合法 JSON：$($_.Exception.Message)")
    }

    if ($null -ne $catalog) {
        if ($catalog.sourceLanguage -ne "zh-Hans") {
            $failures.Add("sourceLanguage 必须为 zh-Hans，实际为：$($catalog.sourceLanguage)")
        }

        $catalogKeys = @($catalog.strings.PSObject.Properties.Name)
        foreach ($entry in $catalog.strings.PSObject.Properties) {
            $languages = @($entry.Value.localizations.PSObject.Properties.Name)
            if ($languages.Count -ne 1 -or $languages[0] -ne "zh-Hans") {
                $failures.Add(
                    "目录 key $($entry.Name) 的语言条目必须且只能是 zh-Hans，实际为：$($languages -join ', ')"
                )
                continue
            }

            $stringUnit = $entry.Value.localizations."zh-Hans".stringUnit
            if ($null -eq $stringUnit -or [string]::IsNullOrEmpty($stringUnit.value)) {
                $failures.Add("目录 key $($entry.Name) 缺少非空 zh-Hans 字符串")
            }
        }
    }
}

$swiftDirectories = @(
    (Join-Path $sourceRoot "App"),
    (Join-Path $sourceRoot "Core"),
    (Join-Path $sourceRoot "Services"),
    (Join-Path $sourceRoot "Features")
)
$swiftFiles = @(
    $swiftDirectories |
        Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
        ForEach-Object { Get-ChildItem -LiteralPath $_ -Filter "*.swift" -File -Recurse }
)

$diagnosticReasons = [ordered]@{
    "资产标识集合不得为空" = "SubmissionSnapshot 开发时前置条件"
    "资产标识必须唯一" = "SubmissionSnapshot 开发时前置条件"
    "资产数量必须等于资产标识数量" = "SubmissionSnapshot 开发时前置条件"
    "已知总字节数不得为负" = "SubmissionSnapshot 开发时前置条件"
    "不可用数量超出资产数量" = "SubmissionSnapshot 开发时前置条件"
    "体积显示模式与不可用数量不一致" = "SubmissionSnapshot 开发时前置条件"
    "收藏集合必须是资产集合的子集" = "SubmissionSnapshot 开发时前置条件"
    "体积字节数不得为负" = "DecimalVolumeFormatter 开发时前置条件"
    "缓存中的已知字节数不得为负" = "S3StateMachine 开发时前置条件"
    "非终态不能交接" = "S4StateMachine 开发时断言"
    "终态交接前必须写入下游目标状态" = "S4StateMachine 开发时断言"
    "扫描服务只能返回终态结论" = "CleanupCoordinator 开发时断言"
}

$literalPattern = '"((?:\\.|[^"\\])*)"'
$hanPattern = '[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]'
$uiLiteralPattern = '(?:Text|Button|Label|Section|ProgressView|navigationTitle|alert|confirmationDialog|accessibility(?:Label|Hint|Value))\s*\(\s*"((?:\\.|[^"\\])*)"'
$dataLiteralPattern = '(?:message\s*(?:=|:)|return)\s*"((?:\\.|[^"\\])*)"'

foreach ($file in $swiftFiles) {
    $relativePath = $file.FullName.Substring($projectRoot.Length + 1).Replace("\", "/")
    $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8)
    $inGeometryDiagnosticProtocol = $false
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $lineNumber = $index + 1
        if ($relativePath -eq "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift" -and
            $line -match '^final class S2GeometryDiagnosticsRun') {
            $inGeometryDiagnosticProtocol = $true
        }

        foreach ($match in [regex]::Matches($line, $literalPattern)) {
            $value = $match.Groups[1].Value
            if ($value -notmatch $hanPattern) {
                continue
            }

            if ($inGeometryDiagnosticProtocol) {
                $diagnostics.Add([PSCustomObject]@{
                    Path = $relativePath
                    LineNumber = $lineNumber
                    Value = $value
                    Reason = "几何诊断导出协议字段"
                })
            }
            elseif ($diagnosticReasons.Contains($value)) {
                $diagnostics.Add([PSCustomObject]@{
                    Path = $relativePath
                    LineNumber = $lineNumber
                    Value = $value
                    Reason = $diagnosticReasons[$value]
                })
            }
            else {
                Add-Residual $relativePath $lineNumber $value "含汉字的产品源码字符串"
            }
        }

        foreach ($match in [regex]::Matches($line, $uiLiteralPattern)) {
            $value = $match.Groups[1].Value
            if ($catalogKeys -notcontains $value) {
                Add-Residual $relativePath $lineNumber $value "UI API 直接使用未入目录的字符串"
            }
        }

        foreach ($match in [regex]::Matches($line, $dataLiteralPattern)) {
            $value = $match.Groups[1].Value
            if ($inGeometryDiagnosticProtocol) {
                continue
            }
            $isLockedVolumeFormat = $relativePath -eq "PhotoCleanupMVE/Core/S3StateMachine.swift" -and
                ($value.EndsWith(" GB") -or $value.EndsWith(" MB"))
            if ($isLockedVolumeFormat) {
                $specExemptions.Add([PSCustomObject]@{
                    Path = $relativePath
                    LineNumber = $lineNumber
                    Value = $value
                    Reason = "十进制 MB/GB 向下截断由规格锁定，本卡禁止本地化改造"
                })
            }
            elseif ($catalogKeys -notcontains $value) {
                Add-Residual $relativePath $lineNumber $value "用户消息或展示 helper 直接返回字符串"
            }
        }
    }
}

$referencedKeys = [System.Collections.Generic.List[string]]::new()
foreach ($file in $swiftFiles) {
    $source = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    $matches = [regex]::Matches(
        $source,
        'L10n\.text\(\s*"([^"]+)"',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    foreach ($match in $matches) {
        $referencedKeys.Add($match.Groups[1].Value)
    }
}
$uniqueReferencedKeys = @($referencedKeys | Sort-Object -Unique)

foreach ($key in $uniqueReferencedKeys) {
    if ($catalogKeys -notcontains $key) {
        $failures.Add("源码引用了目录中不存在的 key：$key")
    }
}
foreach ($key in $catalogKeys) {
    if ($uniqueReferencedKeys -notcontains $key) {
        $failures.Add("目录存在未被产品源码引用的 key：$key")
    }
}

$metadataBoundaries = [System.Collections.Generic.List[object]]::new()
$infoPath = Join-Path $sourceRoot "Info.plist"
if (Test-Path -LiteralPath $infoPath -PathType Leaf) {
    [xml]$info = Get-Content -LiteralPath $infoPath -Raw -Encoding UTF8
    $nodes = @($info.SelectSingleNode("/plist/dict").ChildNodes)
    for ($index = 0; $index -lt $nodes.Count - 1; $index++) {
        if ($nodes[$index].Name -ne "key") {
            continue
        }
        $key = $nodes[$index].InnerText
        if ($key -notin @("CFBundleDisplayName", "NSPhotoLibraryUsageDescription")) {
            continue
        }
        $metadataBoundaries.Add([PSCustomObject]@{
            Path = "PhotoCleanupMVE/Info.plist"
            Key = $key
            Value = $nodes[$index + 1].InnerText
            Reason = "Bundle 或系统权限元数据不由 Localizable.xcstrings 驱动，不属于 S3/S4/S5 页面源码扫描范围"
        })
    }
}

Write-Host "String Catalog 与用户可见硬编码扫描结果"
Write-Host "  - sourceLanguage：$($catalog.sourceLanguage)"
Write-Host "  - 目录条目：$($catalogKeys.Count)"
Write-Host "  - 产品源码引用 key：$($uniqueReferencedKeys.Count)"
Write-Host "  - 用户可见硬编码残留：$($residuals.Count)"
Write-Host "  - 非用户界面断言诊断：$($diagnostics.Count)"
Write-Host "  - 规格锁定格式豁免：$($specExemptions.Count)"
Write-Host "  - Info.plist 范围边界：$($metadataBoundaries.Count)"

if ($residuals.Count -gt 0) {
    Write-Host "用户可见硬编码残留：" -ForegroundColor Red
    foreach ($item in $residuals) {
        Write-Host "  - $($item.Path):$($item.LineNumber) [$($item.Reason)] $($item.Value)" -ForegroundColor Red
    }
}

Write-Host "确认的非用户界面断言诊断："
foreach ($item in $diagnostics) {
    Write-Host "  - $($item.Path):$($item.LineNumber) [$($item.Reason)] $($item.Value)"
}

Write-Host "规格锁定格式豁免："
foreach ($item in $specExemptions) {
    Write-Host "  - $($item.Path):$($item.LineNumber) [$($item.Reason)] $($item.Value)"
}

Write-Host "Info.plist 范围边界："
foreach ($item in $metadataBoundaries) {
    Write-Host "  - $($item.Path) [$($item.Key)] $($item.Value)；$($item.Reason)"
}

if ($failures.Count -gt 0 -or $residuals.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "错误：$failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "扫描通过：用户可见硬编码残留为 0，目录 key 与产品源码引用一致。" -ForegroundColor Green
exit 0
