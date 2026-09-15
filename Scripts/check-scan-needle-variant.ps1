#Requires -Version 5.1
<#
.SYNOPSIS
IC-149 子项 C 门禁二：扫描 needle 与源码变体的交叉审计。

.DESCRIPTION
对应 #295 的死因。测试里的 `strippedSource(...)` 会把字符串字面量的**引号
与内容整个剔掉**（`Image("x")` 剔成 `Image()`）。若把一个**只可能出现在
字面量内部**的 needle 喂给这种剔过的源码，命中数恒为 0：

  - 断言写成「命中 > 0」⇒ 永远失败，真红（#295 的 IC148 三条即此）
  - 断言写成「命中 == 0」⇒ 永远成立，**空转通过**，什么都没测

两种病都出自同一个错误，本门禁一并抓。

判定口径：
  1. 逐函数追踪局部绑定。`let x = ... strippedSource(...)` 记为 stripped；
     `let x = ... sourceText(...)` 记为 raw；由 stripped 名派生的（如
     `let hero = slice(view, ...)`）随之记为 stripped。同名重新绑定即覆盖，
     函数边界即复位——**不这样做，一个文件里 `source` 在 A 函数是 stripped、
     在 B 函数是 raw，就会互相串味**（本门禁初版在 IC146/147/148 上假红三处，
     死因正是名字作用域拉通到了整个文件）。
  2. needle 形如「只可能落在字面量里」才判红：自带引号（`Image("`）、
     文案 key 形（`s0.home.hero.empty.action`）、含中文或全角、资源文件名形
     （`.png` 等）。`"Material"`、`"enum S0HomeMetrics"`、`"case .failed:"`
     这类标识符／代码片段 needle 在剔过的源码里**本来就该命中**，不判红。

.PARAMETER Path
要扫描的目录。默认扫 PhotoCleanupMVETests。

.PARAMETER SelfTest
先跑自带的负对照：真红型与空转型两个合成病样必须各判红，健康样本
（标识符 needle 喂 stripped、key needle 喂 raw）必须零命中。
G854：没有负对照的门禁不算数。

.OUTPUTS
退出码 0 = 通过；1 = 有判红项或自对照失败。
#>
param(
    [string[]]$Path,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:QuoteChar = [char]34
$script:BackslashChar = [char]92

$script:FunctionPattern = '^\s*(?:@\w+\s+)*(?:private\s+|fileprivate\s+|internal\s+|public\s+|static\s+|final\s+|override\s+|class\s+)*func\s+'
$script:BindingPattern = '\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$'
$script:CallPattern = '\boccurrences\s*\(\s*of:\s*(.+?),\s*in:\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)'

$script:CatalogKeyPattern = '^[a-z][a-z0-9]*(\.[a-z0-9_]+){2,}$'
$script:CjkPattern = '[\p{IsCJKUnifiedIdeographs}\p{IsCJKSymbolsandPunctuation}\p{IsHalfwidthandFullwidthForms}]'
$script:ResourceNamePattern = '\.(png|jpg|jpeg|heic|json|pdf|plist|xcstrings)$'

function Get-LogicalLine {
    <#
      把物理行并成逻辑行：只按小括号与方括号的深度续行，**不按大括号**。
      按大括号续行会把整个函数体并成一行，局部绑定与调用点就再也分不开。
      并行时字符串内的括号不计（`"if x != .failed {"` 里的花括号不算）。
      返回对象带 Text 与 LineNumber 两个字段。
    #>
    param([string[]]$Lines)

    $result = [System.Collections.Generic.List[object]]::new()
    $buffer = [System.Collections.Generic.List[string]]::new()
    $depth = 0
    $startLine = 0

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ($buffer.Count -eq 0) {
            $startLine = $index + 1
        }
        $line = $Lines[$index]
        $length = $line.Length
        $cursor = 0
        $kept = [System.Text.StringBuilder]::new()

        while ($cursor -lt $length) {
            $current = $line[$cursor]
            $next = [char]0
            if ($cursor + 1 -lt $length) {
                $next = $line[$cursor + 1]
            }
            if ($current -eq '/' -and $next -eq '/') {
                break
            }
            if ($current -eq $script:QuoteChar) {
                [void]$kept.Append($current)
                $cursor++
                while ($cursor -lt $length) {
                    if ($line[$cursor] -eq $script:BackslashChar) {
                        [void]$kept.Append($line[$cursor])
                        if ($cursor + 1 -lt $length) {
                            [void]$kept.Append($line[$cursor + 1])
                        }
                        $cursor += 2
                        continue
                    }
                    [void]$kept.Append($line[$cursor])
                    if ($line[$cursor] -eq $script:QuoteChar) {
                        $cursor++
                        break
                    }
                    $cursor++
                }
                continue
            }
            if ($current -eq '(' -or $current -eq '[') { $depth++ }
            if ($current -eq ')' -or $current -eq ']') { $depth-- }
            [void]$kept.Append($current)
            $cursor++
        }

        $buffer.Add($kept.ToString().Trim())
        if ($depth -le 0) {
            $result.Add([pscustomobject]@{
                Text       = ($buffer -join " ").Trim()
                LineNumber = $startLine
            })
            $buffer.Clear()
            $depth = 0
        }
    }

    if ($buffer.Count -gt 0) {
        $result.Add([pscustomobject]@{
            Text       = ($buffer -join " ").Trim()
            LineNumber = $startLine
        })
    }

    return ,$result
}

function Get-LiteralOnlyReason {
    param([string]$NeedleBody)

    $reasons = [System.Collections.Generic.List[string]]::new()
    if ($NeedleBody.Contains([string]$script:BackslashChar + [string]$script:QuoteChar)) {
        $reasons.Add("needle 自带引号")
    }
    if ($NeedleBody -cmatch $script:CatalogKeyPattern) {
        $reasons.Add("文案 key 形")
    }
    if ($NeedleBody -match $script:CjkPattern) {
        $reasons.Add("含中文或全角字符")
    }
    if ($NeedleBody -imatch $script:ResourceNamePattern) {
        $reasons.Add("资源文件名形")
    }
    return ,$reasons
}

function Get-ScanNeedleFinding {
    param([string]$FilePath, [string]$DisplayPath)

    $findings = [System.Collections.Generic.List[string]]::new()
    $lines = [System.IO.File]::ReadAllLines($FilePath, [System.Text.Encoding]::UTF8)
    $stripped = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($logical in (Get-LogicalLine -Lines $lines)) {
        $text = $logical.Text

        if ($text -match $script:FunctionPattern) {
            $stripped.Clear()
        }

        $bindingMatch = [regex]::Match($text, $script:BindingPattern)
        if ($bindingMatch.Success) {
            $name = $bindingMatch.Groups[1].Value
            $initializer = $bindingMatch.Groups[2].Value
            if ($initializer.Contains("strippedSource(")) {
                [void]$stripped.Add($name)
            } elseif ($initializer.Contains("sourceText(")) {
                [void]$stripped.Remove($name)
            } else {
                $derived = $false
                foreach ($known in $stripped) {
                    if ($initializer -match ("\b" + [regex]::Escape($known) + "\b")) {
                        $derived = $true
                        break
                    }
                }
                if ($derived) {
                    [void]$stripped.Add($name)
                } else {
                    [void]$stripped.Remove($name)
                }
            }
        }

        foreach ($call in [regex]::Matches($text, $script:CallPattern)) {
            $needle = $call.Groups[1].Value.Trim()
            $haystack = $call.Groups[2].Value.Trim()
            if ($needle.Length -lt 2) { continue }
            if ($needle[0] -ne $script:QuoteChar) { continue }
            if ($needle[$needle.Length - 1] -ne $script:QuoteChar) { continue }
            if (-not $stripped.Contains($haystack)) { continue }

            $body = $needle.Substring(1, $needle.Length - 2)
            $reasons = Get-LiteralOnlyReason -NeedleBody $body
            if ($reasons.Count -gt 0) {
                $findings.Add(
                    "needle 只可能出现在字符串字面量内（$($reasons -join '、')），却喂给了剔除字面量的源码变体 '${haystack}'，命中数恒为 0：${DisplayPath}:$($logical.LineNumber) needle=${needle}"
                )
            }
        }
    }

    return ,$findings
}

function Invoke-NeedleSelfTest {
    $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ic149-needle-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
    $selfTestFailures = [System.Collections.Generic.List[string]]::new()
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    try {
        # 病样一（真红型）：文案 key 喂给剔过的源码，命中恒 0，断言「> 0」必失败。
        $sickRedLines = @(
            'final class SickRedTests: XCTestCase {',
            '    func testCatalogKeyAgainstStrippedSource() throws {',
            '        let view = try XCTUnwrap(',
            '            strippedSource("PhotoCleanupMVE/Features/S0/S0View.swift")',
            '        )',
            '        XCTAssertGreaterThan(',
            '            occurrences(of: "s0.home.hero.empty.action", in: view),',
            '            0',
            '        )',
            '    }',
            '}'
        )
        $sickRedPath = Join-Path $temporaryRoot "SickRedTests.swift"
        [System.IO.File]::WriteAllLines($sickRedPath, $sickRedLines, $utf8NoBom)

        # 病样二（空转型）：`Image("` 喂给剔过的源码并断言「== 0」，永远成立。
        $sickVacuousLines = @(
            'final class SickVacuousTests: XCTestCase {',
            '    func testImageLiteralAgainstStrippedSource() throws {',
            '        let body = try XCTUnwrap(',
            '            strippedSource("PhotoCleanupMVE/Features/S0/S0CategoryRow.swift")',
            '        )',
            '        XCTAssertEqual(occurrences(of: "Image(\"", in: body), 0)',
            '    }',
            '}'
        )
        $sickVacuousPath = Join-Path $temporaryRoot "SickVacuousTests.swift"
        [System.IO.File]::WriteAllLines($sickVacuousPath, $sickVacuousLines, $utf8NoBom)

        # 健康样本：标识符 needle 喂 stripped（合法），同一个 key needle 喂
        # raw（合法）。第二个函数是关键——它证明本门禁分辨的是**干草堆**，
        # 不是只看 needle 长相；且验证同名 `source` 跨函数不串味。
        $healthyLines = @(
            'final class HealthyTests: XCTestCase {',
            '    func testIdentifierNeedlesAgainstStrippedSource() throws {',
            '        let source = try XCTUnwrap(',
            '            strippedSource("PhotoCleanupMVE/Features/S0/S0View.swift")',
            '        )',
            '        XCTAssertEqual(occurrences(of: "ultraThinMaterial", in: source), 0)',
            '        XCTAssertGreaterThan(occurrences(of: "enum S0HomeMetrics", in: source), 0)',
            '    }',
            '',
            '    func testCatalogKeyAgainstRawSource() throws {',
            '        let source = try XCTUnwrap(',
            '            sourceText("PhotoCleanupMVE/Features/S0/S0View.swift")',
            '        )',
            '        XCTAssertGreaterThan(occurrences(of: "s0.home.hero.empty.action", in: source), 0)',
            '    }',
            '}'
        )
        $healthyPath = Join-Path $temporaryRoot "HealthyTests.swift"
        [System.IO.File]::WriteAllLines($healthyPath, $healthyLines, $utf8NoBom)

        $sickRedFindings = Get-ScanNeedleFinding -FilePath $sickRedPath -DisplayPath "SickRedTests.swift"
        if ($sickRedFindings.Count -lt 1) {
            $selfTestFailures.Add("负对照失败：真红型病样（文案 key 喂 stripped）没有判红")
        } else {
            Write-Host "  OK 负对照一（真红型）判红：$($sickRedFindings[0])"
        }

        $sickVacuousFindings = Get-ScanNeedleFinding -FilePath $sickVacuousPath -DisplayPath "SickVacuousTests.swift"
        if ($sickVacuousFindings.Count -lt 1) {
            $selfTestFailures.Add("负对照失败：空转型病样（带引号的 Image 前缀喂 stripped 且断言命中为 0）没有判红")
        } else {
            Write-Host "  OK 负对照二（空转型）判红：$($sickVacuousFindings[0])"
        }

        $healthyFindings = Get-ScanNeedleFinding -FilePath $healthyPath -DisplayPath "HealthyTests.swift"
        if ($healthyFindings.Count -ne 0) {
            $selfTestFailures.Add("正对照失败：健康样本被误判 $($healthyFindings.Count) 项：$($healthyFindings -join '；')")
        } else {
            Write-Host "  OK 正对照（标识符喂 stripped、key 喂 raw）零命中"
        }
    } finally {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    return ,$selfTestFailures
}

$projectRoot = Split-Path -Parent $PSScriptRoot

if ($SelfTest) {
    Write-Host "门禁二（扫描 needle 与源码变体）自对照："
    $selfTestFailures = Invoke-NeedleSelfTest
    if ($selfTestFailures.Count -gt 0) {
        foreach ($failure in $selfTestFailures) {
            Write-Host "  - $failure" -ForegroundColor Red
        }
        exit 1
    }
}

if (-not $PSBoundParameters.ContainsKey("Path") -or $null -eq $Path -or $Path.Count -eq 0) {
    $Path = @((Join-Path $projectRoot "PhotoCleanupMVETests"))
}

$allFindings = [System.Collections.Generic.List[string]]::new()
$scannedCount = 0
foreach ($root in $Path) {
    if (-not (Test-Path -LiteralPath $root)) {
        continue
    }
    foreach ($file in Get-ChildItem -LiteralPath $root -Filter "*.swift" -File -Recurse) {
        $scannedCount++
        $displayPath = $file.FullName
        if ($displayPath.StartsWith($projectRoot)) {
            $displayPath = $displayPath.Substring($projectRoot.Length + 1).Replace("\", "/")
        }
        foreach ($finding in (Get-ScanNeedleFinding -FilePath $file.FullName -DisplayPath $displayPath)) {
            $allFindings.Add($finding)
        }
    }
}

if ($allFindings.Count -gt 0) {
    Write-Host "扫描 needle 与源码变体交叉审计失败，共 $($allFindings.Count) 项：" -ForegroundColor Red
    foreach ($finding in $allFindings) {
        Write-Host "  - $finding" -ForegroundColor Red
    }
    exit 1
}

Write-Host "扫描 needle 与源码变体交叉审计通过：扫描 $scannedCount 个测试源文件，无 needle 喂错源码变体。" -ForegroundColor Green
exit 0
