# IC-148 自验报告 · S0 视觉层（氛围底与玻璃卡、hero 与四态版式、分段条、类别行）

## 结论（先行）

**四个子项全部交付，十四条断言逐条在 CI 绿灯中核过 `passed`，闸门 G847／G848／G849 满足。**

CI 运行 **#296**（id `34944609578`），被测提交 `3d6597807f7b90e25f584f159c4ed353a37f123b`，**iPhone 16 / iOS 26.2 模拟器**：**Executed 791 tests, with 0 failures**（= `main` 基线 777 + 本卡新增 14），真实退出码 **0**，IPA **1569392** 字节。本地三条门禁退出码均为 **0**。登记值对账 **52 : 52**，逐个同名、无遗漏、无自造。

**CI 用满 3 次（预算 3 次），两次红都是执行端自己的缺陷，不是产品缺陷**：#294 红在**编译期**（用 Git Bash heredoc 打补丁，反斜杠被吞，`"
}
"` 落成真换行）；#295 编译通过、791 项跑齐，红在本卡测试自己的三条口径错（把只存在于字符串字面量里的文案 key 拿去扫「剔过字面量」的源码，恒为 0）外加既有的 `testIC063` 计时脆弱用例。#296 一次全绿，且 `testIC063` 本身也 `passed`。详见第五节第 2 部分。

人工判定项 H71 六条一律保留给 Lynn 真机判定，执行端不代为下结论。判定第 1 条前请先读第九节末段关于顶排 chrome 的说明。

---

## 一、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260914-148-s0-visual-layer.md` |
| 规格依据 | `SPEC-S0-20260913_v1.md`，实读 SHA-256 `f5d643653403746590ee1133ebb90a89469e14e73d5cb50974d346cccf852282`（与任务卡登记值一致，大小写差异为 `sha256sum` 输出格式）第三节显示元素清单、第十四节第 2／3 部分 |
| 同层引用 | SPEC-S2 v20 决策 61（氛围底配方、恒深色）；Decision_log 第 166 条、第 170 条裁定 1 与裁定 3 |
| 继承提交 | `main` = `6400666ec9cea250bfbf3a48d52f82db1fcfcba1` |
| 开工核对 | `git log --oneline -1 main` = `6400666 Merge branch 'feature/ic-147-s0-behavior-layer' (IC-147)`，标题以 `Merge branch 'feature/ic-147-s0-behavior-layer'` 开头 ✅；`git merge-base --is-ancestor f41add9cdd16b9402e6cb2a7df7b5f96f9b45713 main` 退出码 **0** ✅ |
| 工作树 | 开工前 `git status --porcelain` 空 ✅（纪律 8） |
| 目标分支 | `feature/ic-148-s0-visual-layer`，自上述 `main` 切出 |
| 五个提交 | A `c3e3b808da5dc5978c308be601338b545a2cc34d`／B `8aa67e7413026f835edcc493439dc56b5697f897`／C `7eed138bee9caa8ec843201cf2022a30d3a34903`／D `45a59cad26453026267e77b170dced7bb6d4afe3`／修 `dc0dfe0722ed49dff6f61f2c542740867c9d3ec7` 与 `3d6597807f7b90e25f584f159c4ed353a37f123b` |
| 被测提交 | `3d6597807f7b90e25f584f159c4ed353a37f123b`（分支 tip） |
| 现状基数 | `main` 上 XCTest **777** 项（IC-147 合并后 `main` 自动运行 #293） |

**范围边界（本卡只做「空间清理」首页的视觉层，不改任何行为）**：状态机、迁移表、点击有效性、数据源协议与桩一行未动（12 个零改动文件两侧 SHA-256 见第八节）。不做类别页与组视图版式（批次 5.2）、真实扫描服务与类别封面真图、待删篮体积真值（批次 5.1，等 H68）、核对流程本体与 `VF` 复位路径（批次 5.3）、账户页／升级页／额度弹窗、S1 顶排换装（IC-149）、浅色模式配方（裁定 甲：首页不提供）。

---

## 二、十四条断言与测试函数名

测试文件 `PhotoCleanupMVETests/IC148S0VisualTests.swift`，共 **14 个测试函数**，与任务卡断言一一对应。

| 断言 | 内容 | 测试函数名 | CI 日志 `passed` |
|---|---|---|---|
| 1 | 52 个登记常量与 SPEC-S0 §14.2 逐条对账，恰 52 个、出处 ≥52 次 | `testIC148AAssertion01RegistryMatchesSpecSection14` | ✅ 0.004s |
| 2 | 恒深色：七项禁用词零命中 + 幕底色／五个类别色两 trait 同值 | `testIC148AAssertion02AlwaysDarkRecipe` | ✅ 0.022s |
| 3 | 零裸数：六个视图体内数值字面量 ⊆ {0,1,2} | `testIC148AAssertion03NoBareNumbersInViewBodies` | ✅ 0.020s |
| 4 | 复用不复制：`Features/S0/` PhotoKit 零命中，氛围底三件被引用 | `testIC148AAssertion04ReusesAmbientWithoutCopyingOrTouchingPhotoKit` | ✅ 0.017s |
| 5 | 四态显示元素清单逐条 | `testIC148BAssertion05FourStateElementLists` | ✅ 0.006s |
| 6 | 首帧口径：判据取可清理字节而非已扫张数 | `testIC148BAssertion06ScanningHeroHidesZeroByteValue` | ✅ 0.034s |
| 7 | 不自造 chrome：圆钮／胶囊命中 S1 helper，新文件内零 chrome 常量族 | `testIC148BAssertion07DoesNotInventChromeVocabulary` | ✅ 0.010s |
| 8 | 宽度分配：五种数据下段宽之和恒为 1 | `testIC148CAssertion08SegmentWidthsAlwaysSumToOne` | ✅ 0.001s |
| 9 | 斜纹：只画在等待清空 > 0 的段，宽度 = 等待清空(c)/LIB | `testIC148CAssertion09HatchOnlyOnPendingSegments` | ✅ 0.003s |
| 10 | 文案门禁：`s0.` 恰 32 条、互为子集、两条新 key 各被引用 | `testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys` | ✅ 0.168s |
| 11 | `VF` 不自造：新文件零推进／复位调用，行为调用点不变，视图内无定时器 | `testIC148CAssertion11NeverAdvancesOrResetsVerification` | ✅ 0.012s |
| 12 | 排序与沉底 | `testIC148DAssertion12SortsByBytesAndSinksEmptyCategories` | ✅ 0.001s |
| 13 | 可点外观与第 170 条裁定 1 一致，并与机器侧交叉断言 | `testIC148DAssertion13TappableAppearanceMatchesClickMatrix` | ✅ 0.001s |
| 14 | 占位不造假：零图片资源名／取图调用，模型无 `coverAssetID` | `testIC148DAssertion14CoverSlotIsEmptyNotFaked` | ✅ 0.012s |

### 本机预验证（②样本观察，不替代 CI）

本机无 Xcode。按任务卡建议移植了断言 1／2／3／4／5／6／7／10／11／14 的源码扫描部分与断言 8／9 的宽度算术，另加两道结构预检：

| 预检 | 覆盖 | 结果 |
|---|---|---|
| `simulate_ic148.py` | 上述断言的源码扫描与算术，**逐调用与 Swift 同源**（同一 needle、同一源码变体） | 全通过 |
| `check_swift_strings.py` | 十个触及文件的「行末仍在单行字符串内」检测 + 花括号／圆括号配平 | 全通过 |
| needle 变体审计 | 逐个比对每次 `occurrences(of:in:)` 的 needle 性质与所用源码变体，MISMATCH 须为 0 | 0 |

**这三道预检各自抓到过一处真缺陷**，详见第五节第 2 部分；但它们**不构成「测试会通过」的证据**，权威结论只取 CI。

---

## 三、52 个登记常量与 SPEC-S0 v1 第十四节第 2 部分逐条对账

脚本核验结论：**52 : 52**，SPEC 本卡范围内字段 52 个、`S0HomeMetrics` 常量 52 个，**未匹配到规格字段的常量为空、规格字段未被登记的为空、常量名与字段名不同的为空**——即逐个同名、无遗漏、无自造。

排除项：`S0Ambient` 十个值（裁定 丙，引用 `S2AmbientMetrics`）、类别页网格 6 值与组视图 5 值（批次 5.2，范围外）；三者在 `S0HomeMetrics` 内均零命中（断言 1 已钉）。

| # | SPEC-S0 v1 §14.2 字段 | 规格值 | `S0HomeMetrics` 常量 | 一致 |
|---|---|---|---|---|
| 1 | `cardBlurRadius` | `30.0` | `cardBlurRadius` | ✅ |
| 2 | `cardSaturation` | `1.70` | `cardSaturation` | ✅ |
| 3 | `cardInnerTopOpacity` | `0.42` | `cardInnerTopOpacity` | ✅ |
| 4 | `cardInnerBottomOpacity` | `0.06` | `cardInnerBottomOpacity` | ✅ |
| 5 | `cardOuterRingOpacity` | `0.10` | `cardOuterRingOpacity` | ✅ |
| 6 | `cardShadowOpacity` | `0.42` | `cardShadowOpacity` | ✅ |
| 7 | `cardShadowRadius` | `40.0` | `cardShadowRadius` | ✅ |
| 8 | `cardShadowYOffset` | `14.0` | `cardShadowYOffset` | ✅ |
| 9 | `segmentBarHeight` | `8.0` | `segmentBarHeight` | ✅ |
| 10 | `segmentBarCornerRadius` | `4.0` | `segmentBarCornerRadius` | ✅ |
| 11 | `segmentBarItemSpacing` | `3.0` | `segmentBarItemSpacing` | ✅ |
| 12 | `segmentBarInnerHighlightOpacity` | `0.35` | `segmentBarInnerHighlightOpacity` | ✅ |
| 13 | `segmentHatchAngleDegrees` | `135.0` | `segmentHatchAngleDegrees` | ✅ |
| 14 | `segmentHatchStripeWidth` | `3.0` | `segmentHatchStripeWidth` | ✅ |
| 15 | `segmentHatchGapWidth` | `3.0` | `segmentHatchGapWidth` | ✅ |
| 16 | `segmentRestOpacity` | `0.22` | `segmentRestOpacity` | ✅ |
| 17 | `segmentUnscannedOpacity` | `0.10` | `segmentUnscannedOpacity` | ✅ |
| 18 | `legendDotSide` | `8.0` | `legendDotSide` | ✅ |
| 19 | `legendDotCornerRadius` | `2.5` | `legendDotCornerRadius` | ✅ |
| 20 | `legendFontSize` | `12.0` | `legendFontSize` | ✅ |
| 21 | `legendItemSpacingH` | `14.0` | `legendItemSpacingH` | ✅ |
| 22 | `legendItemSpacingV` | `6.0` | `legendItemSpacingV` | ✅ |
| 23 | `pendingRowHeight` | `40.0` | `pendingRowHeight` | ✅ |
| 24 | `pendingRowCornerRadius` | `20.0` | `pendingRowCornerRadius` | ✅ |
| 25 | `pendingRowLeadingInset` | `14.0` | `pendingRowLeadingInset` | ✅ |
| 26 | `pendingRowFontSize` | `13.0` | `pendingRowFontSize` | ✅ |
| 27 | `pendingButtonHeight` | `28.0` | `pendingButtonHeight` | ✅ |
| 28 | `pendingButtonCornerRadius` | `14.0` | `pendingButtonCornerRadius` | ✅ |
| 29 | `pendingButtonFontSize` | `12.5` | `pendingButtonFontSize` | ✅ |
| 30 | `categoryRowHeight` | `78.0` | `categoryRowHeight` | ✅ |
| 31 | `categoryRowCornerRadius` | `24.0` | `categoryRowCornerRadius` | ✅ |
| 32 | `categoryRowSpacing` | `8.0` | `categoryRowSpacing` | ✅ |
| 33 | `categoryCoverSide` | `60.0` | `categoryCoverSide` | ✅ |
| 34 | `categoryCoverCornerRadius` | `16.0` | `categoryCoverCornerRadius` | ✅ |
| 35 | `categoryColorDotSide` | `8.0` | `categoryColorDotSide` | ✅ |
| 36 | `categoryNameFontSize` | `17.0` | `categoryNameFontSize` | ✅ |
| 37 | `categorySubFontSize` | `12.5` | `categorySubFontSize` | ✅ |
| 38 | `categorySubOpacity` | `0.52` | `categorySubOpacity` | ✅ |
| 39 | `categoryValueFontSize` | `24.0` | `categoryValueFontSize` | ✅ |
| 40 | `categoryValueUnitFontSize` | `12.0` | `categoryValueUnitFontSize` | ✅ |
| 41 | `categoryDisabledOpacity` | `0.45` | `categoryDisabledOpacity` | ✅ |
| 42 | `heroLabelFontSize` | `15.0` | `heroLabelFontSize` | ✅ |
| 43 | `heroValueFontSize` | `96.0` | `heroValueFontSize` | ✅ |
| 44 | `heroValueLetterSpacing` | `-5.5` | `heroValueLetterSpacing` | ✅ |
| 45 | `heroUnitFontSize` | `26.0` | `heroUnitFontSize` | ✅ |
| 46 | `heroSubFontSize` | `14.0` | `heroSubFontSize` | ✅ |
| 47 | `heroSubOpacity` | `0.50` | `heroSubOpacity` | ✅ |
| 48 | `colorBigVideo` | `#6E9BFF` | `colorBigVideo` | ✅ |
| 49 | `colorSimilar` | `#3FD1B0` | `colorSimilar` | ✅ |
| 50 | `colorScreenshot` | `#FFB54A` | `colorScreenshot` | ✅ |
| 51 | `colorScreenRecording` | `#C89BFF` | `colorScreenRecording` | ✅ |
| 52 | `colorDuplicate` | `#FF8FA3` | `colorDuplicate` | ✅ |

---

## 四、点击外观与行为层的一致性（断言 13）

| 类别状态 | 行暗度 | 数值位 | 进入指示 | 机器侧 `acceptsCategoryRowTap`（S0-1） |
|---|---|---|---|---|
| `.counting`、有项目 | 1（不压暗） | 字节量 | 有 | **true**（第 170 条裁定 1） |
| `.awaitingScanCompletion` | 0.55（SPEC-S0 §3.1 正文） | 「—」 | 无 | **false** |
| `.settled`、无项目 | 0.45（`categoryDisabledOpacity`） | 字节量 | 无 | false |

呈现层与行为层在同一个测试函数里交叉断言；**`testIC147BAssertion06ClickMatrixEveryCell` 的任何期望值未改**。

---

## 五、CI

### 1. 绿灯读数（#296）

| 项 | 值 |
|---|---|
| 运行编号 | **#296**，run id `34944609578`，attempt 1（job id `104300941619`） |
| 被测提交 | `3d6597807f7b90e25f584f159c4ed353a37f123b`（完整 40 位，存在性核验见第十一节） |
| 目的地实证行 | `使用 iPhone 模拟器：iPhone 16 (id=2911FD29-A09E-4A81-BEA7-99A616FB7FC8, runtime=com.apple.CoreSimulator.SimRuntime.iOS-26-2)` |
| XCTest 项数与失败数 | **Executed 791 tests, with 0 failures (0 unexpected) in 31.325 (36.969) seconds** |
| 项数对账 | 791 = `main` 基线 **777**（#293）+ 本卡新增 **14**；日志内唯一 `Test Case … passed` 计数 **791**、唯一 `Test Case … failed` 计数 **0**，与执行摘要一致 |
| 摘要 notice | 有；且 `Test Suite 'All tests' started` 只出现 **1** 次（单段运行，摘要即总数——该复核口径见 IC-147 报告第五节第 3 部分） |
| 真实退出码 | 步骤「运行 XCTest」`conclusion=success`，日志末尾打出 `XCTest 已全部通过`，无 `Process completed with exit code` 错误行 |
| 十个步骤 | 全部 `success`（含结构自验、硬编码扫描、构建未签名应用、上传 IPA） |
| IPA 校验 | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1569392，SHA-256=b08845f6c50572359ca9318af5192db81d88c1914c41c8b0922e194b3bd8bc43` |

**G849 要求逐条贴的四条既有测试**（均在 #296 `passed`，一字未改除 key 计数外的任何断言）：

```
Test Case '-[PhotoCleanupMVETests.IC146ChromeRoundTwoTests testIC146B_AmbientMetricsMatchS0AmbientRegistry]' passed (0.004 seconds).
Test Case '-[PhotoCleanupMVETests.IC146ChromeRoundTwoTests testIC146B_AmbientRecipeIsIdenticalInBothColorSchemes]' passed (0.004 seconds).
Test Case '-[PhotoCleanupMVETests.IC147S0BehaviorTests testIC147BAssertion06ClickMatrixEveryCell]' passed (0.001 seconds).
Test Case '-[PhotoCleanupMVETests.IC147S0BehaviorTests testIC147CAssertion11EveryS0StringGoesThroughTheCatalog]' passed (0.005 seconds).
```

本卡 14 项的逐条 `passed` 耗时已填入第二节表格右列。IC-146 的 20 项与 IC-147 的 16 项**全部 `passed`**，其中 IC-147 只改了 key 计数相关的四处（change-list 第六节），IC-146 一字未改。

### 2. 两次判红的归因（#294、#295）——**都是执行端缺陷，不是产品缺陷**

| 运行 | 阶段 | 失败内容 | 归因 |
|---|---|---|---|
| **#294** | 编译期 | `IC148S0VisualTests.swift` 十处 `unterminated string literal` 等 | 本机用 Git Bash heredoc 往 Swift 里打补丁，heredoc **吞掉反斜杠**，`"
}
"` 落成一个真换行。产品代码未参与，测试未运行 |
| **#295** | 断言 | 本卡断言 5（两处）、断言 6（一处）假红；`testIC063` 两处 | 前三处：`strippedSource` 会把**字符串字面量内容连同引号一并剔掉**，而文案 key 恰恰写在字面量里，拿剔过的源码找 key 恒为 0。后者见第十节第 6 条 |

**#295 同时暴露了一处「空转通过」**：断言 14 的 `Image("`／`.png`／`.jpg` 也只可能出现在字面量里，扫剔过的源码恒为 0，于是那条「零命中」是**过得没有意义**的。已一并改为扫原文，并补了正对照。

**处置与加固**（本机预检，②样本观察）：

1. 凡 needle 本身是 key、资源名或中文措辞的，一律改扫 `sourceText` 原文，变量名带 `raw` 前缀。
2. 新增 **needle 变体审计**：逐个比对每次 `occurrences(of:in:)` 的 needle 性质与所用源码变体，MISMATCH 须为 0（当前为 0）。
3. 新增 **`check_swift_strings.py`**：逐行跟踪字符串状态，报「行末仍在单行字符串内」，并统计花括号／圆括号配平——这正是 #294 那类 heredoc 损坏的直接探针。
4. 本机模拟器改成与 Swift **逐调用同源**（此前它对那三处用的是原文，所以没能预报 #295）。

**另一处本机就抓到、没进 CI 的缺陷**：断言 3 的 `numericLiterals` 扫描器最初在「数字属于标识符」分支里按「是否字母或下划线」推进指针，而当前字符是数字 ⟹ 指针不动、**循环不终止**，会把 XCTest 挂死。本机移植跑同一逻辑时先卡到超时才暴露。跳过标识符的判据必须含数字。

---

## 六、本地门禁

| 门禁 | 命令 | 真实退出码 | 结果 |
|---|---|---|---|
| 结构自验 | `.\Scripts\selfcheck.ps1` | **0** | 通过 |
| 硬编码扫描 | `.\Scripts\scan-hardcoded-user-visible-strings.ps1` | **0** | 通过：目录条目 **247**、产品源码引用 key **247**、用户可见硬编码残留 **0** |
| 空白检查 | `git diff --check` | **0** | 无输出 |

三条都在最后一次修正提交之后**重跑过**，上表是重跑后的读数。行尾与 BOM：本卡触及的全部文件均为 LF、无 BOM（字节计数 `CR=0`）。

---

## 七、G847／G848／G849 闸门

见第八节（零改动文件两侧 SHA-256、App 入口两个 hunk、pbxproj 登记）与第二节（断言逐条）。G849 要求逐条贴的四条既有测试 `passed` 行见第五节。

---

## 八、G847／G848 证据

### 零改动文件两侧 SHA-256（12 个，逐个 SAME）

| 文件 | `main` 与 tip 同值 |
|---|---|
| **`Features/S2/S2AmbientBackdrop.swift`**（裁定 丙必列） | `ee5ed62d36d1fe69264a8aeae8d66ba345a3df71417d1e3b16f1709ae7813006` |
| `Features/S2/S2View.swift` | `12bc93f1d3271ce7899bcef664f06e9c314fdaebbb850e1aac325e3291edbe91` |
| `Features/S2/S2Calibration.swift` | `b06168a00987d70d17e9a41b2525a5fce18a0f2cb081c1d70576e7382087410f` |
| `Features/S1/S1View.swift` | `7a5913e45528ae2fa910667848fdc183033b531ac3b1ec0f76e909ae08172c7a` |
| `Features/S3/S3View.swift` | `881d1c74472f3019d9cc2177e2c61d57668d30ebe0863395012cecd9e57b87ff` |
| `Features/S4/S4View.swift` | `91edeef270e6fd47f6b30ce53b7704471fb8170c35abf9d6f4e518c2ee12df37` |
| `Features/S5/S5View.swift` | `c37f6795d3e86644a4b555d7dcd2709b86e48ccd858eca3cac23c6abc15f4acf` |
| `Core/S0StateMachine.swift` | `45cec85bca12aa271fc1ef6db200c212d89207e04c2e9e1ac906b065d1c0b374` |
| `Core/S1StateMachine.swift` | `b6c747919c10e91b6032b3d41556f9875f26a0fad9562b68fd53a91cec7e6cd3` |
| `Core/S2StateMachine.swift` | `90ddffad6ab737bbe00ea1c1cb1cb402503949c45cb5080e55b483a248dfe032` |
| `Services/S0CleanupDataStub.swift` | `53ea990b26835e81413e4123cf59897a744cd3f8b5539cd5198c91ddb176acc4` |
| `Services/AssetSizeScanner.swift` | `9eca40ff4915761097307f58182ee654bcb5ddd02e6e45cf990448b6b557999d` |

`S2Calibration.swift` 不在 diff，`S2CalibrationConfiguration.schemaVersion` 仍 **7**。

### 冻结三链与三条探针分支远端 tip（未变）

| 分支 | 远端 tip |
|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` |
| `probe/ic-067-screenshot-subtype` | `9db02b93eccbb87d126602901807e70823535111` |
| `probe/ic-137-media-playback` | `486bcb769b59eb1146c5a231c7998847206777cc` |
| `probe/ic-145-scan-service` | `d373afc7125104c01acfc296829229090e6871ce` |

### App 入口两个 hunk

`git diff main..HEAD -U0` 对 `App/PhotoCleanupMVEApp.swift` 只输出两个 `@@`：

| hunk | 内容 |
|---|---|
| `@@ -18,0 +19,5 @@` | E1：新增 `s0AmbientImageProvider` 注入（5 行，含 3 行注释） |
| `@@ -73,0 +79 @@` | E2：`s0Screen()` 实参加 `ambientImageProvider:` 一行，位置与 `S0View` 逐成员声明顺序一致 |

合计 6 增 0 删。`tabContainer`、`s1Screen`、`s2Screen`、路由 switch 五分支、`.onAppear`、`restoreS0Foreground` 一字未动。

### pbxproj 登记

五个新文件各恰 **4** 处登记（`grep -c` 行计）；对象定义行**无重复 id**。加登记前重扫的各族最大 id 与新占用见 change-list 第五节。

### `Features/S0/` PhotoKit 零命中（G848）

七个符号（`import Photos`／`PHAsset`／`PHPhotoLibrary`／`PHImageManager`／`PHFetch`／`PHCachingImageManager`／`PHAssetResource`）在 `S0View`／`S0SegmentBar`／`S0CategoryRow`／`S0HomeMetrics`／`S0TabContainer` 五个文件内**各为 0**；正对照 `Services/S0RecentPhotoAmbientLoader.swift` 内 `PHAsset` 与 `import Photos` 均 ≥ 1。

---

## 九、人工判定项（H71，留给 Lynn 真机，执行端不代为下结论）

1. 「空间清理」页有氛围底：一张强模糊的自己的照片压在深色幕下，有颗粒感；**深色/浅色系统外观下切换，页面一样深**。
2. hero 大字、分段条与图例、类别行三组内容各自在玻璃卡上，层次分得开；分段条的斜纹段能看出来。
3. 四个态都看一遍：扫描中（有「未扫描」段与「统计中」副行）、就绪、无可清理项目（有「去逐张整理」入口）、失败（只有失败说明，没有 hero 与分段条）。
4. 类别行按体积从大到小排，「无项目」的灰着沉在底部点不动；**S0-1 下「重复／相似」两行是暗的、数值显示「—」，其余类别行点得进去**。
5. **两处已知的未完成，确认它们是「空着」而不是「错着」**：类别行的封面位是占位（不是错图、不是别人的照片）；待删篮胶囊体积读零。两者都等批次 5.1。
6. 回归：切到「逐张整理」再切回来，S1 与 S2／S3 行为与 IC-147 后完全一致；H70 五项复看一遍。

**以上六条一律保留给 Lynn 真机判定，执行端不代为下结论。**

判定第 1 条时请注意：**顶排的圆钮与胶囊是 S1 的 chrome 玻璃**（子项 B 第 5 条要求引用 S1 的三个 helper），而 S1 的 helper 在 iOS 26 以下走 `.ultraThinMaterial`、iOS 26 走 `glassEffect`，**这两者都随系统外观变**。裁定 甲 的「恒深色」覆盖的是氛围底、玻璃卡、分段条、类别行，**不覆盖 chrome**。因此切浅色时页面主体仍是深的，但顶排那两件可能跟着变浅——这是两条卡内要求叠加后的必然结果，不是缺陷；若不可接受需决策会话另裁。

---

## 十、发现但未处理的问题

按纪律只报告不修。

1. **任务卡断言 11 与子项 B／C 自相矛盾。** 断言 11 要求 `S0View` 的 `machine.` 调用点数量与 IC-147 交付时**完全相同**；但子项 B 第 6 条要求新画受限提示条（必须读 `lim`），子项 C 要求新画分段条（必须读账本与照片库总占用）。两者不可同时满足。**处置**：钉**行为**调用点不变——`machine.handle(` 4 处、`machine.beginVerification` 1 处、`machine.ingest` 1 处，与 IC-147 交付时逐一相同（6 : 6）；只读访问的增减逐项列出：

   | 成员 | IC-147 | IC-148 | 增减 |
   |---|---|---|---|
   | `machine.snapshot` | 8 | 9 | +1（分段条模型一次性读快照） |
   | `machine.orderedCategories` | 1 | 2 | +1（分段条与类别行各一次） |
   | `machine.isLimitedAuthorization` | 0 | 1 | +1（受限提示条） |
   | `machine.state` | 2 | 1 | −1（收敛为 `homeState` 一处） |
   | 合计 `machine.` | 28 | 30 | +2 |

   **无一处是写入**。请决策会话确认该处置，或改写断言 11 的口径。

2. **SPEC-S0 v1 第十四节第 3 部分没有受限提示条的 `s0.` key。** 子项 B 第 6 条要求画这条，而「未登记的文案不得出现」是第二节的共同不变量。本卡复用 SPEC-S1 v9 已登记的同义文案 `s1.limited.banner`（「仅可整理你选中的照片」），并把这**唯一一条**跨前缀引用在 `IC147S0BehaviorTests` 断言 11 里钉死，再多一条即判红。**建议 SPEC-S0 v2 补登一条 `s0.` 受限提示条文案。**

3. **`S1LimitedBannerPresentation` 不可复用。** 任务卡子项 B 第 6 条写「引用 `S1LimitedBannerStyle`／`S1LimitedBannerPresentation`」，但后者的 `isVisible(isLimitedAuthorization:state:)` 形参是 **`S1State`**，与 S0 的四态不是同一枚举，S0 侧取不到。本卡只引用了 `S1LimitedBannerStyle`（几何），显隐按 SPEC-S0 v1 第三节的显示元素清单自判（S0-1／S0-2／S0-3 显示，S0-4 不显示）。

4. **登记表七处缺口（第十四节第 2 部分没给，本卡按同页同族的已登记值代用）。** 逐条见 change-list 第七节：玻璃卡的**圆角与内边距**、**全部前景色**、图例的**项内间隙**、「正在扫描…」／空态主句／失败说明三句的**字号**、封面占位态的**描边取值**，以及写在第三节正文而非登记表的 **55% 行暗度**与**「—」占位符号**。每一处都在代码里写明了出处与代用理由，无一处凭印象填数。**建议 SPEC-S0 v2 一并补登。**

5. **玻璃卡的磨砂层是「同一张氛围图的第二份副本」，不是真正的背景模糊。** 登记表给了 `cardBlurRadius` 30 与 `cardSaturation` 1.70，这两个值描述的是一层背景磨砂；而 SwiftUI 里唯一现成的背景磨砂是系统材质，**恰好被裁定 甲 禁用**（系统材质随 trait 变）。本卡的取法是：卡内铺幕底色，再把氛围底那张图按这两个登记值模糊+提饱和后裁进卡形。它**不与卡后面的像素严格对齐**（是同源图的独立副本），观感上是「同一张照片的磨砂面板」。H71 第 2 条请据此判断层次是否分得开；若要求严格对齐的真背景模糊，需决策会话重新裁定裁定 甲 与登记值的关系。

6. **`testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages` 再次判红。** 与 IC-147 报告第十节第 11 条同一只计时脆弱用例。本卡 #295 上它报「双击进入 Nx 动画中间帧 2 < 3」，耗时 3.376 秒（#291 上 3.923 秒通过）。CLAUDE.md 已把它列入待开的 CI 稳定性卡，并约定「红在该用例上时先对同一提交原样复跑做对照」。本卡未改它一行。

7. **`S0SegmentBarModel` 对「各类别字节之和超过 `LIB`」做了夹断。** `c.bytes` 是**全量不去重**的（SPEC-S0 第二节第 2 部分），各类别之和完全可能超过照片库总占用；不夹断会让段宽之和 > 1、「其余照片」为负。本卡按「按序取到预算用尽为止」处理，断言 8 覆盖了该情形。**规格没有写明超出时怎么办**，此处是执行端取定的收敛方式，请决策会话确认。

8. **就绪且有项目的类别行没有副行文案。** SPEC-S0 第三节第 2 部分要求副行给「项数、组数、等待清空量」，但第十四节第 3 部分**没有登记该情形的副行 key**（只登记了「无项目」「统计中」「扫描完成后开始识别」三种）。IC-147 曾把体积读数放在副行；本卡按子项 D 第 1 条把体积移到右侧值位（两个登记字号），副行**留空**而不是重复画同一个数字。待补登记后再填。

---

## 十一、全部 40 位 SHA 的存在性核验

报告与 change-list 内出现的每个 40 位提交 SHA，逐个跑 `git cat-file -e <sha>^{commit}`（陷阱 15：40 位 SHA 不得凭短前缀补全）：

| SHA | 身份 | `git cat-file -e` |
|---|---|---|
| `6400666ec9cea250bfbf3a48d52f82db1fcfcba1` | 继承提交（`main`，IC-147 merge） | **exit 0**（存在） |
| `f41add9cdd16b9402e6cb2a7df7b5f96f9b45713` | IC-147 被测提交（祖先核对用） | **exit 0**（存在） |
| `c3e3b808da5dc5978c308be601338b545a2cc34d` | 本卡子项 A | **exit 0**（存在） |
| `8aa67e7413026f835edcc493439dc56b5697f897` | 本卡子项 B | **exit 0**（存在） |
| `7eed138bee9caa8ec843201cf2022a30d3a34903` | 本卡子项 C | **exit 0**（存在） |
| `45a59cad26453026267e77b170dced7bb6d4afe3` | 本卡子项 D | **exit 0**（存在） |
| `dc0dfe0722ed49dff6f61f2c542740867c9d3ec7` | 修 #294 编译错误 | **exit 0**（存在） |
| `3d6597807f7b90e25f584f159c4ed353a37f123b` | 修 #295 假红＝被测提交＝分支 tip | **exit 0**（存在） |

冻结三链与三条探针分支的六个 tip（第八节）同样来自 `git ls-remote origin` 的实读输出。

---

## 十二、G850 合并前置核对

| 条目 | 结果 |
|---|---|
| G847（diff 限白名单、12 个文件零改动含 `S2AmbientBackdrop.swift`、App 入口只两个 hunk） | ✅ 见第八节 |
| G848（52 值对账表进报告、三视图体零裸数、`Features/S0/` PhotoKit 零命中、`schemaVersion` 7、冻结链与探针分支未变） | ✅ 见第三／八节与断言 1／3／4 |
| G849（恒深色七词零命中 + 幕底色两 trait 同值；IC-146 的 20 项与 IC-147 的 16 项除 key 计数外一字未改且全 `passed`，四条逐条贴出） | ✅ 见第五节第 1 部分 |
| 全部 XCTest 通过 | ✅ 791 项 0 失败 |
| 真实退出码 0 | ✅ 步骤 success + `XCTest 已全部通过` |
| 摘要 notice | ✅ `Executed 791 tests, with 0 failures` |
| iOS 26.2 / iPhone 16 目的地实证行 | ✅ 见第五节 |
| IPA 字节数与 SHA-256 | ✅ 1569392 字节，`b08845f6…bc43` |
| 断言 1～14 逐条给函数名并在日志核 `passed` | ✅ 见第二节 |
| 登记值对账 52 : 52 | ✅ 见第三节 |
| 工作树净 | ✅ `git status --porcelain` 仅有未跟踪的 `Reports/IC-148/`（本卡报告，随后以 docs 提交入库） |
| `main` 未被他人推进 | ✅ `git ls-remote origin refs/heads/main` = `6400666ec9cea250bfbf3a48d52f82db1fcfcba1`，与继承提交一致 |

**G850 判定：满足。** 合并结果见第十三节。

---

## 十三、合并与 G851

**合并已完成。**

| 项 | 值 |
|---|---|
| 合并提交 | `5c7c56c4264e10c2b7e514cd943a5602e728364c`（`Merge branch 'feature/ic-148-s0-visual-layer' (IC-148)`，`--no-ff`） |
| 合并前 `main` | `6400666ec9cea250bfbf3a48d52f82db1fcfcba1`（与继承提交一致，未被他人推进） |
| 合并后 `main` | `5c7c56c4264e10c2b7e514cd943a5602e728364c`，已推送 |
| 树一致性 | `git diff --stat feature/ic-148-s0-visual-layer HEAD` **无输出**——合并后 `main` 的树与被测分支 tip 逐字节一致 |
| 合并规模 | 12 files changed, 3295 insertions(+), 94 deletions(-) |

**G851（合并后 `main` 自动运行）**：

| 项 | 值 |
|---|---|
| 运行编号 | **#297**，run id `34946151007` |
| 被测提交 | `5c7c56c4264e10c2b7e514cd943a5602e728364c`（合并提交本身） |
| 结论 | **success**，十个步骤无一失败 |
| XCTest | **Executed 791 tests, with 0 failures (0 unexpected) in 36.992 (47.441) seconds** |
| IPA | 1569392 字节，SHA-256 `80c010d30bcfff4cdadbe4671949b666dbd136083561e8b7bf22e6c799060047` |

**IPA 字节数与 #296 相同（1569392）而 SHA-256 不同**，与项目既有结论一致：IPA 归档不可复现，**不得用 IPA 哈希做跨运行的同一性判据**，同一性以树 diff 为准（上表「树一致性」行）。

> 本节为**合并后才产生的信息**，按纪律 7 以同一张卡的 docs 提交回填；因合并已落在 `main` 上，该 docs 提交直接落 `main`（`Reports/**` 命中 `paths-ignore`，不触发 CI，是预期行为）。
