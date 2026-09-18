# IC-159 变更清单

## 一、概要

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260917-159-testic063-pipeline-warmup.md` |
| 基线 `main` | `15bf53f042a30a1ace0dfea2cf289973f019c67d` |
| 分支 | `feature/ic-159-testic063-pipeline-warmup` |
| 子项 T 提交 | `b7b1b738224f54d563e09bb352743257f2741a1e` `IC-159 T：testIC063 计时导出前先跑一次丢弃的预热导出` |
| 报告 | 本文件与 `self-check.md`，另一个 docs 提交（同一分支，纪律 7：CI 编号推送后才产生；SHA 在 `self-check.md` 第十一节实读补记） |
| 产品目录 | **零改动**。`PhotoCleanupMVE/` 全部 49 个文件两侧 SHA-256 相同（第五节聚合表） |
| 出厂值 | **无变更**。`S2CalibrationConfiguration.schemaVersion` 仍 **7**；`S0ScanRules.cacheSchemaVersion` 仍 **1**；`S0HomeMetrics` 仍 **52**；`S0CategoryPageMetrics` 仍 **42**；本卡不加常量、不加用例（XCTest 仍 852 项） |
| 占位值登记 | **无**。本卡不新增 `factoryPlaceholder` 项、不改任何出厂值集合，故不递增 `schemaVersion`（第六节纪律的前提未触发） |

## 二、文件清单（`git diff --numstat 15bf53f b7b1b73`）

| 文件 | 增／删 | 白名单条目 | 所属提交 |
|---|---|---|---|
| `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` | **+28／−0** | T2（仅插入块） | T |

合计 1 个路径，+28／−0。报告两份另计（docs 提交，`Reports/IC-159/`，白名单第二条）。

`git diff --name-only 15bf53f b7b1b73` 输出恰一行，即上表该文件；`git diff --check` 退出码 0。

## 三、逐项变更

### 子项 T（`PhotoCleanupMVETests/S2CalibrationHarnessTests.swift`）

| 处 | 改后行 | 变更 |
|---|---|---|
| T2 | `:4139-4166`（新增 28 行） | 在挂载断言的右括号（`:4138` `        )`）之后、10 s 计时循环（改前 `:4139`、改后 `:4167`）之前，逐字插入任务卡裁定 二给出的 28 行预热块 |

插入块原文（与任务卡 ```swift 代码块**逐字节相同**，本机以 Python 比对确认 `IDENTICAL`）：

```swift
        // IC-159：预热导出——模拟器着色器缓存失效后，双击过渡首次渲染要同步编译
        // Metal 管线（`path_exterior`，七次运行实测 0.57～30.8 s），落在计时段内即红。
        // 先完整跑一次导出并丢弃，编译落在这里；下面的计时导出在同一进程里不再编译。
        guard diagnostics.isExporting || !diagnostics.reportText.isEmpty else {
            return // 挂载断言已红，不再叠加失败行
        }
        let warmUpDeadline = Date(timeIntervalSinceNow: 60)
        while diagnostics.isExporting, Date() < warmUpDeadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        guard !diagnostics.isExporting else {
            XCTFail("预热导出未在 60 s 内完成")
            return
        }
        let warmUpReport = diagnostics.reportText
        XCTAssertFalse(warmUpReport.isEmpty, "预热导出没有产出报告")
        let warmUpGateLines = warmUpReport.components(separatedBy: "\n").filter {
            $0.hasPrefix("采样总数：") || $0.hasPrefix("中间帧门禁：") ||
                $0.hasPrefix("错误：") || $0.hasPrefix("中间帧软目标未达：")
        }
        print("IC063_WARMUP_GATE_BEGIN")
        print(warmUpGateLines.joined(separator: "\n"))
        print("IC063_WARMUP_GATE_END")
        diagnostics.export()
        XCTAssertTrue(
            diagnostics.isExporting || diagnostics.reportText != warmUpReport,
            "计时导出没有起飞"
        )
```

### 既有行的行号位移（无内容变更）

| 既有行 | 改前 | 改后 | 内容 |
|---|---|---|---|
| 函数首 | `:4089` | `:4089` | `func testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages()` |
| 挂载循环 + 挂载断言（T1） | `:4126-4138` | `:4126-4138` | 逐字不变（它调的第一次 `export()` 即预热） |
| 10 s 计时循环 | `:4139-4142` | `:4167-4170` | `let deadline = Date(timeIntervalSinceNow: 10)` 起，逐字不变 |
| `XCTAssertFalse(diagnostics.isExporting)` | `:4145` | `:4173` | 逐字不变 |
| `report.contains("中间帧门禁：通过")` | `:4146` | `:4174` | 逐字不变 |
| 样本打印 | `:4191` | `:4219` | 逐字不变 |
| 函数末 | `:4192` | `:4220` | `    }` |

既有行逐字不变由本机三条逐行比对证明（详见 `self-check.md` 第四节）：改后 `:4089-4138` ≡ 基线 `:4089-4138`；改后 `:4167-4220` ≡ 基线 `:4139-4192`；从改后文件删去 `:4139-4166` 这 28 行即逐字重现基线全文件。

## 四、未触碰项（白名单之外，两侧同一对象）

| 对象 | `15bf53f` | `b7b1b73` | 判定 |
|---|---|---|---|
| `PhotoCleanupMVE/`（产品目录树） | `87aec05f066b973f9224282a8edb1795fb09c454` | 同 | 同一 tree |
| `.github/` | `74088388c62a10eb277921ecf74e766a2d407e80` | 同 | 同一 tree |
| `Scripts/` | `514886dc0afc4083237c976c0f7be6ce597c50a8` | 同 | 同一 tree |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `edda3f5252c6d29df6a0b892db82fe9788c36d46` | 同 | 同一 blob |
| 其余测试文件 | — | — | `git diff --name-only` 只列本卡那一个文件 |
| `feature/ic-158-diagnostic-progress-clamp` | tip `5cb67332437a446d98733ddc942e2905392d2891` | 未动 | 未 cherry-pick、未删、未改（开工时在该分支上，已先 `git switch -c` 到本卡分支） |
| SPEC / `Decision_log.md` | — | — | 未读写（顶层目录，不在仓库内） |

## 五、G902 产品目录聚合 SHA-256 表

口径：`git ls-tree -r <rev> -- PhotoCleanupMVE/` 逐 blob 取内容 SHA-256，按路径升序拼成 `"<path> <sha256> <bytes>"` 行表，再对行表整体取 SHA-256。

| 范围 | 文件数 | `15bf53f` 聚合 SHA-256 | `b7b1b73` 聚合 SHA-256 |
|---|---|---|---|
| `PhotoCleanupMVE/` 全部 | 49 | `27348CE8BEFCBB9FFB9AD3211CD49626DA065E2E7C5993A725500556F6D26523` | 同 |
| `PhotoCleanupMVE/App/` | 2 | `AFC4F94933B1CC06FCE72BEF598EF9F3FE51DB3818F63B6E810583E70EE69F84` | 同 |
| `PhotoCleanupMVE/Core/` | 10 | `7405D80AB45961B1B1FB004B27145D364E398910EBFB54489461F7A57FDC42E6` | 同 |
| `PhotoCleanupMVE/Services/` | 11 | `6F113A974FAF25FA012B565772536C1BE631AB750B9A59654383FAAD24854892` | 同 |
| `PhotoCleanupMVE/Features/` | 23 | `E5DED6774DADBA903A318E8AF1C86BA5F4C6A0C5DC9B89AFFE4F441BC3142026` | 同 |

单文件（逐文件 SHA-256，49 项两侧全同，抽两项列出）：

| 文件 | SHA-256（两侧相同） |
|---|---|
| `PhotoCleanupMVE/Localizable.xcstrings` | `C58D4323265CD84820ED36EDB92FD7DFE6169140962CAEDF91B6469DA0C50406` |
| `PhotoCleanupMVE/Info.plist` | `E7D657EB1BEB4D22A6F11DA5A8FA775D075DA6E8B98E5A1A9CFBB121445A65F0` |

`Features/S2/S2NativePhotoPager.swift` 含在 `Features/` 聚合内，两侧同一 blob（产品目录整树 SHA 相同即逐文件相同，脚本另逐文件比对 `per-file identical: True`）。

## 六、文案与登记

- `Localizable.xcstrings` **未改**（本卡新增的汉字全部是测试文件内的注释、`XCTFail`／`XCTAssert` 失败描述与 `hasPrefix` 判据，不是用户可见文案）。
- 硬编码扫描器只扫 `PhotoCleanupMVE/{App,Core,Services,Features}`，不扫测试目录；本机 `scan-hardcoded-user-visible-strings.ps1` 退出码 0。
- 登记制常量：本卡不增不改（`S0HomeMetrics` 52、`S0CategoryPageMetrics` 42、`S2AmbientMetrics` 十二值均未触碰）。

## 七、CI 与合并

见 `self-check.md`（运行编号、被测提交、项数与失败数、真实退出码、目的地实证行、IPA 校验、分段耗时 notice、裁定 三的五项材料、合并提交与 G904）。
