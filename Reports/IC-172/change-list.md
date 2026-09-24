# IC-172 变更清单

**状态：停卡上报，未合并。** 分支 `feature/ic-172-glass-always-dark`，tip `a01ffe616396750a091c8d22dd8497d9f4983922`，`main` 未变（仍为 `467fe74a0323c98e938142a2107f16843d21cc96`）。详细归因见 `self-check.md`。

## 一、提交列表（各自独立，顺序 A→B→C→D）

| 序 | SHA | 摘要 |
|---|---|---|
| A | `6308693920a4e180f74559549c2606b8539d1ba0` | 两个玻璃 helper（`s1/s2ChromeGlassBackground` 与 `s1/s2LegacyChromeGlassBackground`）各在返回子树链尾追加 `.environment(\.colorScheme, .dark)` |
| B | `e89b95a248e6bc47224c4c7c3929b196b3219794` | 五个玻璃容器（S1 `chromeBar`／`s1GlassBadgeOverlay`／`s1GlassBadgeHost`，S2 `topBar`／`actionBar`）容器链尾各加同一覆盖 |
| C | `df10428b74d3e0547dcbe4a30a8623dd14cc236b` | 四处系统材质（S1 写回失败 toast、S1 排序／分组菜单 `menuContainer`；S2 写回失败 toast、S2 相簿 sheet 教程提示条）材质之后加同一覆盖 |
| D | `a01ffe616396750a091c8d22dd8497d9f4983922` | 新增测试 `PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift`（逐字节拷入决策会话生成的文件，`hash-object`=`b49a40de20a2790da747428bce3ae423d316e20d`）；`project.pbxproj` 登记该文件（fileRef `…075`、buildFile `…072`） |

## 二、文件改动一览（白名单，恰 4 路径，与 `git diff --name-only 467fe74a..a01ffe6` 完全一致）

| 路径 | 类型 | 涉及子项 |
|---|---|---|
| `PhotoCleanupMVE/Features/S1/S1View.swift` | 修改 | A、B、C |
| `PhotoCleanupMVE/Features/S2/S2View.swift` | 修改 | A、B、C |
| `PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift` | 新建 | D |
| `PhotoCleanupMVE.xcodeproj/project.pbxproj` | 修改（登记新测试文件） | D |
| `Reports/IC-172/self-check.md`、`Reports/IC-172/change-list.md` | 新建（本次停卡报告，未走合并后 docs 提交，随分支一起推送） | 报告 |

**不涉及**（与卡面「不得打红」段一致，`git diff --name-only` 未出现在改动列表中）：`App/`、`Core/`、`Services/`、除 `S1View.swift`／`S2View.swift` 外的全部 `Features/`（含全部 S0 文件、`S2AmbientBackdrop.swift`、S3／S4／S5）、`Localizable.xcstrings`、`.github/`、`Scripts/`、除新测试文件外的全部测试文件。

## 三、逐文件改动细节

### `PhotoCleanupMVE/Features/S1/S1View.swift`

- A：`s1ChromeGlassBackground` 的 `#available(iOS 26.0, *)` 分支尾部、`s1LegacyChromeGlassBackground` 收尾，各追加 `.environment(\.colorScheme, .dark)`（各带一行中文注释说明依据）。
- B：`chromeBar`／`s1GlassBadgeOverlay`／`s1GlassBadgeHost` 三处 `GlassEffectContainer { ... }` 之后、原有 `.overlay(...)`／`.overlayPreferenceValue(...)` 之前，各插入同一覆盖。
- C：写回失败 toast 的 `.background(.regularMaterial, in: Capsule())` 之后、`menuContainer` 的 `.shadow(...)` 之后，各插入同一覆盖。

累计 `+19` 行（A 5 行 + B 6 行 + C 8 行，含注释）。

### `PhotoCleanupMVE/Features/S2/S2View.swift`

- A：`s2ChromeGlassBackground` 的 `#available(iOS 26.0, *)` 分支尾部、`s2LegacyChromeGlassBackground` 收尾，各追加同一覆盖。
- B：`topBar`／`actionBar` 两处 `GlassEffectContainer { ... }` 之后各插入同一覆盖。
- C：写回失败 toast 的 `.background(.regularMaterial, in: Capsule())` 之后、相簿 sheet 教程提示条的 `.background(.ultraThinMaterial, in: Capsule())` 之后，各插入同一覆盖。

累计 `+15` 行（A 5 行 + B 4 行 + C 6 行，含注释）。**标定面板三处裸 `.background(.regularMaterial)` 未改动**（④ 第 201 条不纳入）。

### `PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift`（新建，364 行）

六条测试：两条正对照（`testIC172A_MaterialControlFollowsInterfaceStyle`、`testIC172A_RawGlassControlFollowsInterfaceStyle`）、三条被测（`testIC172A_S1GlassHelperIsDarkInBothStyles`、`testIC172A_S1LegacyRecipeIsDarkInBothStyles`、`testIC172B_GlassContainerPathIsDarkInBothStyles`）、一条源码落位扫描（`testIC172ABC_SourceWiring`）。逐字节拷自 `<top>/Tasks/decision-tools/IC172GlassAlwaysDarkTests.swift`，未改动任何一行。

### `PhotoCleanupMVE.xcodeproj/project.pbxproj`

新增四行登记（照 IC-171 的写法）：
- `PBXBuildFile`：`200000000000000000000072 /* IC172GlassAlwaysDarkTests.swift（测试源码） */ = {isa = PBXBuildFile; fileRef = 100000000000000000000075 /* IC172GlassAlwaysDarkTests.swift */; };`
- `PBXFileReference`：`100000000000000000000075 /* IC172GlassAlwaysDarkTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = IC172GlassAlwaysDarkTests.swift; sourceTree = "<group>"; };`
- Group 列表：`100000000000000000000075 /* IC172GlassAlwaysDarkTests.swift */,`（紧随 IC171 之后）
- Sources 构建阶段列表：`200000000000000000000072 /* IC172GlassAlwaysDarkTests.swift（测试源码） */,`（紧随 IC171 之后）

## 四、CI 摘要（详见 `self-check.md` 第七节）

| 运行 | commit | 结论 | 项数／失败 | 备注 |
|---|---|---|---|---|
| #349（id `35986967001`） | `df10428` | success | 892／0 | A→B→C，IPA 已产出（1862103 字节，SHA-256 `ca665a10f5963c3d0ff06164c18c33773be6600f18176a369e2ac95e55218c10`） |
| #350（id `35988265755`） | `a01ffe6` | **failure** | 898／1 | D；失败用例 `testIC172A_S1LegacyRecipeIsDarkInBothStyles`；未产出 IPA（构建与上传步骤 skipped） |

## 五、未合并说明

G967（合并前置门禁）要求两次 CI 均绿；本次第二次（898）为 1 处失败，**不满足**。按任务卡「模型阶梯补偿」条款，执行端在此停止，不自行修改代码重推。分支 `feature/ic-172-glass-always-dark` 保留现状（tip `a01ffe6`），`main` 未变。后续处理方式（是否需要新的探针、是否调整测试断言、是否需要另出一张卡）等待决策会话读取本报告与两次运行日志后指示。

## 六、40 位 SHA 核验命令与结果

```
$ git cat-file -e 467fe74a0323c98e938142a2107f16843d21cc96^{commit}   # exit 0
$ git cat-file -e e356aeda17da53a064892e04f39bea1032f5bf8d^{commit}   # exit 0
$ git cat-file -e 6308693920a4e180f74559549c2606b8539d1ba0^{commit}   # exit 0
$ git cat-file -e e89b95a248e6bc47224c4c7c3929b196b3219794^{commit}   # exit 0
$ git cat-file -e df10428b74d3e0547dcbe4a30a8623dd14cc236b^{commit}   # exit 0
$ git cat-file -e a01ffe616396750a091c8d22dd8497d9f4983922^{commit}   # exit 0
$ git cat-file -e b49a40de20a2790da747428bce3ae423d316e20d^{blob}     # exit 0
$ git cat-file -e 99dd6a9ba1170c3b3dcedc26fec2e22850912eb3^{blob}     # exit 0
$ git cat-file -e bea3bf09887428db76827877408a27b09ecf0bb3^{blob}    # exit 0
```

（实际执行输出见执行会话报告贴出的命令记录；全部返回码 0，核验通过。）
