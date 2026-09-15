#Requires -Version 5.1
<#
.SYNOPSIS
IC-149 子项 C 门禁一：Swift 单行字符串闭合与括号配平检查。

.DESCRIPTION
对应 #294 的死因。用 heredoc 往源文件里写 "\n}\n" 这类内容时，shell 会把
反斜杠吞掉，落到文件里就成了一个**真正的换行**——单行字符串字面量于是在
行尾没有闭合。这种错只有编译期才报，代价是一次完整的 CI。本门禁在本机把
它拦下来。

同时校验大括号／小括号／方括号在**字符串与注释之外**是否配平：同一类
heredoc 事故也会吞掉括号，或让一段代码落在字符串里而整体失衡。

扫描口径（模式栈：code / string / interp）：
  - `//` 行注释、`/* */` 块注释（可嵌套）内的内容不计
  - 只在 code 模式下计括号。字符串内的括号不计；插值 `\(...)` 里的括号
    也不计——插值体本身是合法表达式，必然自平，单独计它只会把口径搞乱
  - 插值体内可以再嵌字符串（`"\(a ? "x" : "y")"`），模式栈据此逐层进出。
    **不认插值就会把插值里的引号当成外层字符串的收尾**，S2NativePhotoPager
    的 `"中间帧门禁：\(errors.isEmpty ? "通过" : "失败")"` 即因此被误判过
  - `"""` 多行字符串整段跳过（跨行合法，不判红）

.PARAMETER Path
要扫描的目录。默认扫 PhotoCleanupMVE 与 PhotoCleanupMVETests 两个源码目录。

.PARAMETER SelfTest
先跑自带的负对照：两个合成病样（字符串跨行、括号不配平）必须各判红，
一个健康样本必须判通过。自对照不过即退出 1，不再扫真实源码。
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

function Get-SwiftStructureFinding {
    param([string]$FilePath, [string]$DisplayPath)

    $findings = [System.Collections.Generic.List[string]]::new()
    $lines = [System.IO.File]::ReadAllLines($FilePath, [System.Text.Encoding]::UTF8)

    $blockCommentDepth = 0
    $inMultilineString = $false
    $multilineStartLine = 0
    $brace = 0
    $paren = 0
    $bracket = 0

    # 模式栈：底部恒为 "code"；遇字符串压 "string"，遇插值压 "interp"。
    # interpDepth 与 "interp" 逐层对应，记插值体内已开而未闭的小括号层数。
    $modes = [System.Collections.Generic.List[string]]::new()
    $modes.Add("code")
    $interpDepths = [System.Collections.Generic.List[int]]::new()

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $lineNumber = $index + 1
        $length = $line.Length
        $cursor = 0

        if ($inMultilineString) {
            $closing = $line.IndexOf('"""')
            if ($closing -lt 0) {
                continue
            }
            $inMultilineString = $false
            $cursor = $closing + 3
        }

        while ($cursor -lt $length) {
            $mode = $modes[$modes.Count - 1]
            $current = $line[$cursor]
            $next = [char]0
            if ($cursor + 1 -lt $length) {
                $next = $line[$cursor + 1]
            }

            if ($mode -eq "string") {
                if ($current -eq $script:BackslashChar -and $next -eq '(') {
                    $modes.Add("interp")
                    $interpDepths.Add(0)
                    $cursor += 2
                    continue
                }
                if ($current -eq $script:BackslashChar) {
                    $cursor += 2
                    continue
                }
                if ($current -eq $script:QuoteChar) {
                    $modes.RemoveAt($modes.Count - 1)
                    $cursor++
                    continue
                }
                $cursor++
                continue
            }

            # 以下是 code 与 interp 两种「代码」模式共用的扫描。
            if ($blockCommentDepth -gt 0) {
                if ($current -eq '/' -and $next -eq '*') {
                    $blockCommentDepth++
                    $cursor += 2
                    continue
                }
                if ($current -eq '*' -and $next -eq '/') {
                    $blockCommentDepth--
                    $cursor += 2
                    continue
                }
                $cursor++
                continue
            }

            if ($current -eq '/' -and $next -eq '/') {
                break
            }
            if ($current -eq '/' -and $next -eq '*') {
                $blockCommentDepth = 1
                $cursor += 2
                continue
            }

            if ($current -eq $script:QuoteChar) {
                if ($cursor + 2 -lt $length -and $line.Substring($cursor, 3) -eq '"""') {
                    $inMultilineString = $true
                    $multilineStartLine = $lineNumber
                    $cursor += 3
                    continue
                }
                $modes.Add("string")
                $cursor++
                continue
            }

            if ($mode -eq "interp") {
                if ($current -eq '(') {
                    $interpDepths[$interpDepths.Count - 1] = $interpDepths[$interpDepths.Count - 1] + 1
                    $cursor++
                    continue
                }
                if ($current -eq ')') {
                    if ($interpDepths[$interpDepths.Count - 1] -eq 0) {
                        # 插值体收尾，回到外层字符串。
                        $interpDepths.RemoveAt($interpDepths.Count - 1)
                        $modes.RemoveAt($modes.Count - 1)
                    } else {
                        $interpDepths[$interpDepths.Count - 1] = $interpDepths[$interpDepths.Count - 1] - 1
                    }
                    $cursor++
                    continue
                }
                $cursor++
                continue
            }

            if ($current -eq '{') { $brace++ }
            elseif ($current -eq '}') { $brace-- }
            elseif ($current -eq '(') { $paren++ }
            elseif ($current -eq ')') { $paren-- }
            elseif ($current -eq '[') { $bracket++ }
            elseif ($current -eq ']') { $bracket-- }

            $cursor++
        }

        # 单行字符串必须在本行闭合；`"""` 例外，已在上面单独走。
        if (-not $inMultilineString -and $modes.Count -gt 1) {
            $findings.Add(
                "单行字符串字面量在行尾未闭合（heredoc 吞掉反斜杠后 \n 会落成真换行，编译期才报错）：${DisplayPath}:${lineNumber}"
            )
            # 复位，免得后续每一行都跟着报。
            $modes.Clear()
            $modes.Add("code")
            $interpDepths.Clear()
        }
    }

    if ($inMultilineString) {
        $findings.Add("多行字符串字面量到文件末尾仍未闭合：${DisplayPath}:${multilineStartLine}")
    }
    if ($blockCommentDepth -gt 0) {
        $findings.Add("块注释到文件末尾仍未闭合：${DisplayPath}")
    }
    if ($brace -ne 0) {
        $findings.Add("大括号不配平（净值 ${brace}）：${DisplayPath}")
    }
    if ($paren -ne 0) {
        $findings.Add("小括号不配平（净值 ${paren}）：${DisplayPath}")
    }
    if ($bracket -ne 0) {
        $findings.Add("方括号不配平（净值 ${bracket}）：${DisplayPath}")
    }

    return ,$findings
}

function Invoke-StructureSelfTest {
    $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ic149-structure-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
    $selfTestFailures = [System.Collections.Generic.List[string]]::new()
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    try {
        # 病样一：字符串跨行——正是 heredoc 吞掉反斜杠后 "\n}\n" 的落地形态。
        $sickStringLines = @(
            'enum Sick {',
            '    static let terminator = "',
            '}',
            '"',
            '}'
        )
        $sickStringPath = Join-Path $temporaryRoot "SickUnclosedString.swift"
        [System.IO.File]::WriteAllLines($sickStringPath, $sickStringLines, $utf8NoBom)

        # 病样二：括号不配平（少一个收尾大括号）。
        $sickBraceLines = @(
            'enum SickBrace {',
            '    static func make() -> Int {',
            '        return 1',
            '    }'
        )
        $sickBracePath = Join-Path $temporaryRoot "SickUnbalancedBrace.swift"
        [System.IO.File]::WriteAllLines($sickBracePath, $sickBraceLines, $utf8NoBom)

        # 健康样本：转义引号、插值、插值体内再嵌字符串、注释里的孤立引号与
        # 括号——一条都不得误判。插值内嵌字符串这条是 S2NativePhotoPager
        # 真实写法的缩影，缺了它本门禁会在真实源码上假红。
        $healthyLines = @(
            'enum Healthy {',
            '    static let quoted = "say \"hi\" once"',
            '    static let interpolated = "value=\(1 + 2)"',
            '    static let nested = "gate=\(list.isEmpty ? "pass" : "fail")"',
            '    static let deep = "x=\(make(a: (1 + 2), b: "s"))"',
            '    // 注释里写一个孤立引号 " 和一个孤立括号 ( 都不该被算进去',
            '    static let path = "Assets/icon.png"',
            '}'
        )
        $healthyPath = Join-Path $temporaryRoot "Healthy.swift"
        [System.IO.File]::WriteAllLines($healthyPath, $healthyLines, $utf8NoBom)

        $sickStringFindings = Get-SwiftStructureFinding -FilePath $sickStringPath -DisplayPath "SickUnclosedString.swift"
        if ($sickStringFindings.Count -lt 1) {
            $selfTestFailures.Add("负对照失败：字符串跨行的病样没有判红")
        } else {
            Write-Host "  OK 负对照一（字符串跨行）判红：$($sickStringFindings[0])"
        }

        $sickBraceFindings = Get-SwiftStructureFinding -FilePath $sickBracePath -DisplayPath "SickUnbalancedBrace.swift"
        if ($sickBraceFindings.Count -lt 1) {
            $selfTestFailures.Add("负对照失败：括号不配平的病样没有判红")
        } else {
            Write-Host "  OK 负对照二（括号不配平）判红：$($sickBraceFindings[0])"
        }

        $healthyFindings = Get-SwiftStructureFinding -FilePath $healthyPath -DisplayPath "Healthy.swift"
        if ($healthyFindings.Count -ne 0) {
            $selfTestFailures.Add("正对照失败：健康样本被误判 $($healthyFindings.Count) 项：$($healthyFindings -join '；')")
        } else {
            Write-Host "  OK 正对照（健康样本，含插值内嵌字符串）零命中"
        }
    } finally {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    return ,$selfTestFailures
}

$projectRoot = Split-Path -Parent $PSScriptRoot

if ($SelfTest) {
    Write-Host "门禁一（Swift 字符串与括号结构）自对照："
    $selfTestFailures = Invoke-StructureSelfTest
    if ($selfTestFailures.Count -gt 0) {
        foreach ($failure in $selfTestFailures) {
            Write-Host "  - $failure" -ForegroundColor Red
        }
        exit 1
    }
}

if (-not $PSBoundParameters.ContainsKey("Path") -or $null -eq $Path -or $Path.Count -eq 0) {
    $Path = @(
        (Join-Path $projectRoot "PhotoCleanupMVE"),
        (Join-Path $projectRoot "PhotoCleanupMVETests")
    )
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
        foreach ($finding in (Get-SwiftStructureFinding -FilePath $file.FullName -DisplayPath $displayPath)) {
            $allFindings.Add($finding)
        }
    }
}

if ($allFindings.Count -gt 0) {
    Write-Host "Swift 字符串与括号结构检查失败，共 $($allFindings.Count) 项：" -ForegroundColor Red
    foreach ($finding in $allFindings) {
        Write-Host "  - $finding" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Swift 字符串与括号结构检查通过：扫描 $scannedCount 个 .swift，无未闭合字符串、无括号失衡。" -ForegroundColor Green
exit 0
