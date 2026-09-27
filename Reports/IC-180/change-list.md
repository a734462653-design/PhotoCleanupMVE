# IC-180 变更清单

任务卡：`<top>/Tasks/IC-20260926-180-s5-guide-steps.md`
基线：`main` = `1419065a1a10191d6b223f893d9ecdf8d4a49fc6`
分支：`feature/ic-180-s5-guide-steps`（tip `219be48914b70e13b48941dab5b053028bdcebaf`）
合并：`496835aa998b98e03951d7c039830103689dec98`（`--no-ff`，父 `1419065…` 与 `219be48…`）
CI：分支 #364 绿 930／0；合并后 `main` #365 绿 930／0

## 提交与文件

| 子项 | 提交 | 文件 | 改动 |
|---|---|---|---|
| A 五步模块 | `ecef724f9fd5d4cb7085826df5dcfefb0d0633ce` | `PhotoCleanupMVE/Features/Shared/S5GuideStepsView.swift`（新建） | 逐字节拷入 `Tasks/decision-tools/S5GuideStepsView.swift`：`S5GuideStep`（五 case，`text`／`symbolName`／`isLeadStep`）、`S5GuideSymbol`（五常量）、`S5GuideMetrics`（十二值）、`S5GuideStepsView` |
| | | `PhotoCleanupMVE/Localizable.xcstrings` | `s5.recently_deleted.boundary_notice` 取值改 SPEC-S5 v6 第三节第 1 部分原句；紧随其后新增 `s5.guide.step1`～`step5`（文本替换，未经 JSON 库重写；269 → 274） |
| | | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 产品文件登记四行（PBXBuildFile `200000000000000000000079`、PBXFileReference `10000000000000000000007C`、Shared 组 children、产品 Sources 阶段） |
| B S5View | `6c3c9f5ed67bcac727ae3778e9a2b0a4d4710cee` | `PhotoCleanupMVE/Features/S5/S5View.swift` | `guidanceCard`：首句 `Text` 与 `S5GuideStepsView()` 包进 `VStack(alignment: .leading, spacing: S5GuideMetrics.introBottomSpacing)`，内距与底色挪到 `VStack` 上；首句字号／行高／前景与容器登记不动 |
| C 测试 | `219be48914b70e13b48941dab5b053028bdcebaf` | `PhotoCleanupMVETests/IC180GuideStepsTests.swift`（新建） | 逐字节拷入 `Tasks/decision-tools/IC180GuideStepsTests.swift`，五条测试 |
| | | `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 测试文件登记四行（PBXBuildFile `20000000000000000000007A`、PBXFileReference `10000000000000000000007D`、测试组 children、测试 Sources 阶段） |

白名单路径 5 个，`git diff --name-only 1419065..219be48` 恰此 5 个。

## 最终文件 blob（C 提交 = 合并后 `main` 树）

| 路径 | blob |
|---|---|
| `PhotoCleanupMVE/Features/Shared/S5GuideStepsView.swift` | `dd0c32358a5b6d49e379e5c3bb8e0039b28af595` |
| `PhotoCleanupMVE/Features/S5/S5View.swift` | `070ebe0107122acf07cd5dd506b6639dcd3e6e76` |
| `PhotoCleanupMVE/Localizable.xcstrings` | `9ec88f562791dadf4d4b1eed865b344f7f1333ab` |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | `3026fadfbe82a93e580af70354bceda7b0f0421f` |
| `PhotoCleanupMVETests/IC180GuideStepsTests.swift` | `5ef2eec6827ed367c860f6c5931778747da932a2` |

## 新增文案 key（目录 269 → 274）

| key | 取值 |
|---|---|
| `s5.recently_deleted.boundary_notice`（改值） | 照片仍由系统保留。清空「最近删除」后才真正释放空间。应用无法读取或清空该位置。 |
| `s5.guide.step1` | 打开系统「照片」 |
| `s5.guide.step2` | 进入「精选集」，向下找到「最近删除」 |
| `s5.guide.step3` | 打开「最近删除」 |
| `s5.guide.step4` | 轻点「选择」 |
| `s5.guide.step5` | 轻点「更多 (…)」，选择「全部删除」 |

## 占位值登记

- `S2CalibrationConfiguration.schemaVersion` 仍 **7**（本卡无出厂值变更）。
- 卡内暂登（SPEC-S5 v7 回填）：`S5GuideMetrics` 十二值——`introBottomSpacing` 12、`rowSpacing` 6、`rowMinHeight` 44、`leadSpacing` 14、`numberCircleSide` 28、`numberFontSize` 14、`numberRingWidth` 1.5、`numberRingOpacity` 0.4、`numberTextOpacity` 0.8、`textFontSize` 15、`textLineSpacing` 21、`symbolPointSize` 18；`S5GuideSymbol` 五名——`photo.on.rectangle`、`rectangle.stack`、`trash`、`checkmark.circle`、`ellipsis.circle`（决策会话卡内取定，非 ④）。

## 未改动（按卡保留）

`Core/`、`Services/`、`App/`、`Features/S0`～`S4`、`Features/Shared/` 既有三文件、`.github/`、`Scripts/`、既有 56 个测试文件；`S5CardMetrics`／`S5StateElement`／四态 `elements`；`S0DeckMetrics` 195、`S0DeckSymbol` 8、`S2InlineHintMetrics` 30、`s2.tutorial.` 10、`s0.` 41。操作说明卡与入口（IC-181）、「打开系统「照片」」次要操作、首页「未通过」接线（5.3）不在本卡。
