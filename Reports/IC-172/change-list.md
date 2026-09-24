# IC-172 变更清单

**状态：停卡上报，未合并，CI 预算三次用尽。** 分支 `feature/ic-172-glass-always-dark`，tip `c1ca74f6ceeb8bda2bc31d32b66df0ba759913d3`，`main` 全程未变（`467fe74a0323c98e938142a2107f16843d21cc96`）。归因细节见 `self-check.md`。

## 一、提交列表（各自独立）

| 序 | SHA | 摘要 |
|---|---|---|
| A | `6308693920a4e180f74559549c2606b8539d1ba0` | 两个玻璃 helper（`s1/s2ChromeGlassBackground` 与 `s1/s2LegacyChromeGlassBackground`）各在返回子树链尾追加 `.environment(\.colorScheme, .dark)` |
| B | `e89b95a248e6bc47224c4c7c3929b196b3219794` | 五个玻璃容器（S1 `chromeBar`／`s1GlassBadgeOverlay`／`s1GlassBadgeHost`，S2 `topBar`／`actionBar`）容器链尾各加同一覆盖 |
| C | `df10428b74d3e0547dcbe4a30a8623dd14cc236b` | 四处系统材质（S1 写回失败 toast、S1 排序／分组菜单 `menuContainer`；S2 写回失败 toast、S2 相簿 sheet 教程提示条）材质之后加同一覆盖 |
| D | `a01ffe616396750a091c8d22dd8497d9f4983922` | 新增测试 `PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift`（旧版，`hash-object`=`b49a40de20a2790da747428bce3ae423d316e20d`）；`project.pbxproj` 登记该文件（fileRef `…075`、buildFile `…072`） |
| D′ | `c1ca74f6ceeb8bda2bc31d32b66df0ba759913d3` | 覆盖同一测试文件（新版，`hash-object`=`2c119e174af05d1da15b234720ebbc6e8f205586`），只改 `testIC172A_S1LegacyRecipeIsDarkInBothStyles` 后半段的参照写法与断言；产品代码、pbxproj 不变 |
| （已作废，内容被本报告替换） | `5d581608e94e313230020f959ed172f8f792db51` | #350 红后写的中途停卡报告，纪律 6 完整替换 |

## 二、文件改动一览（恰 4 产品/测试路径 + `Reports/IC-172/` 2 个文件，与 `git diff --name-only 467fe74a..c1ca74f` 完全一致）

| 路径 | 类型 | 涉及子项 |
|---|---|---|
| `PhotoCleanupMVE/Features/S1/S1View.swift` | 修改 | A、B、C |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 修改 | A、B、C |
| `PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift` | 新建（D）、覆盖（D′） | D、D′ |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 修改（登记新测试文件） | D |
| `Reports/IC-172/self-check.md`、`Reports/IC-172/change-list.md` | 新建／完整替换（本次停卡报告） | 报告 |

**不涉及**：`App/`、`Core/`、`Services/`、除 `S1View.swift`／`S2View.swift` 外的全部 `Features/`（含全部 S0 文件、`S2AmbientBackdrop.swift`、S3／S4／S5）、`Localizable.xcstrings`、`.github/`、`Scripts/`、除新测试文件外的全部测试文件。

## 三、D′ 改动细节

`testIC172A_S1LegacyRecipeIsDarkInBothStyles` 函数体后半段：

- 变量名 `material` → `reference`；
- 参照构造从 `.background(.ultraThinMaterial, in: Capsule())`（单表达式）改为 `.background { Capsule().fill(.ultraThinMaterial); Capsule().fill(Color.white.opacity(S1ChromeGlass.tintOpacity)) }`（与产品 `s1LegacyChromeGlassBackground` 的两层 `fill` 写法同构，泛型 `shape` 换成具体 `Capsule()`）；
- 断言由 1 条改 2 条：`abs(reference.light - reference.dark) >= materialMinimumDifference(12)`（参照本身有判别力）与 `abs(legacy.light - reference.dark) <= sameAccuracy(3)`（legacy 应落在深色一侧）。

前半段（`legacy` 的构造与第一条 `abs(legacy.light - legacy.dark) <= sameAccuracy` 断言）与其余五条测试逐字节未动。

## 四、CI 摘要（三次，预算用尽）

| 运行 | commit | 结论 | 项数／失败 | 备注 |
|---|---|---|---|---|
| #349（id `35986967001`） | `df10428` | success | 892／0 | A→B→C，IPA 已产出（1862103 字节，SHA-256 `ca665a10f5963c3d0ff06164c18c33773be6600f18176a369e2ac95e55218c10`） |
| #350（id `35988265755`） | `a01ffe6` | failure | 898／1 | D（旧版参照）；失败于 `testIC172A_S1LegacyRecipeIsDarkInBothStyles`（`XCTAssertLessThan failed: ("50") is not less than ("20")`）；无 IPA |
| #351（id `35991746708`） | `c1ca74f` | **failure（本卡最后一次）** | 898／1 | D′（新版参照）；同一用例再次失败（`XCTAssertLessThanOrEqual failed: ("45") is greater than ("3")`）；无 IPA |

全部 `IC172_PROBE` 行原文（三次运行）见 `self-check.md` 第七节；跨运行归因对读见第八节。

## 五、未合并说明

D′ 节改读的 G967（要求「#349 绿 892／0 + D′ 那次绿 898／0」）在 #351 仍为 898／1，**不满足**。按 D′ 节第 5 条「红：不再推、不合并，停卡报告（三次 CI 用尽，纪律 2）」执行：执行端未再修改测试或产品代码、未再推送。分支 `feature/ic-172-glass-always-dark` 保留现状（tip `c1ca74f`），`main` 未变。#351 的新探针数据（`legacyCenterReference` light=172 dark=104）显示 D′ 节的"写法不同"归因本身并不成立（两种写法在真实 trait 下渲染几乎一致），真正的差距在于 `.environment(\.colorScheme, .dark)` 覆盖下 `Material` 的渲染值（149）既不贴合真实深色也不贴合真实浅色，成因未查明，留待决策会话定下一步（新卡或改变产品实现方式）。

## 六、40 位 SHA 核验命令与结果

```
$ git cat-file -e 467fe74a0323c98e938142a2107f16843d21cc96^{commit}   # exit 0
$ git cat-file -e e356aeda17da53a064892e04f39bea1032f5bf8d^{commit}   # exit 0
$ git cat-file -e 6308693920a4e180f74559549c2606b8539d1ba0^{commit}   # exit 0
$ git cat-file -e e89b95a248e6bc47224c4c7c3929b196b3219794^{commit}   # exit 0
$ git cat-file -e df10428b74d3e0547dcbe4a30a8623dd14cc236b^{commit}   # exit 0
$ git cat-file -e a01ffe616396750a091c8d22dd8497d9f4983922^{commit}   # exit 0
$ git cat-file -e 5d581608e94e313230020f959ed172f8f792db51^{commit}   # exit 0
$ git cat-file -e c1ca74f6ceeb8bda2bc31d32b66df0ba759913d3^{commit}   # exit 0
$ git cat-file -e b49a40de20a2790da747428bce3ae423d316e20d^{blob}     # exit 0
$ git cat-file -e 2c119e174af05d1da15b234720ebbc6e8f205586^{blob}     # exit 0
$ git cat-file -e 99dd6a9ba1170c3b3dcedc26fec2e22850912eb3^{blob}     # exit 0
$ git cat-file -e bea3bf09887428db76827877408a27b09ecf0bb3^{blob}     # exit 0
```
