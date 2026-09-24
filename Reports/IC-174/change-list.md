# IC-174 变更清单

## 一、结论

已合并、已推送。分支 `feature/ic-174-glass-always-dark-reissue`（四提交 A→B→C→D）经 CI #353 一次绿（899／0）后，`--no-ff` 合并入 `main`（合并提交 `39dc8d0be448ea051f37fdb99be8dbae3d35ca35`），合并后 `main` 自动运行 #354 绿（899／0）。

## 二、文件级改动（`git diff --stat 467fe74a0323c98e938142a2107f16843d21cc96 39dc8d0be448ea051f37fdb99be8dbae3d35ca35`）

```
 PhotoCleanupMVE.xcodeproj/project.pbxproj          |   4 +
 PhotoCleanupMVE/Features/S1/S1View.swift           |  16 +
 PhotoCleanupMVE/Features/S2/S2View.swift           |  13 +
 PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift | 448 +++++++++++++++++++++
 4 files changed, 481 insertions(+)
```

恰 4 个白名单路径，0 处越界改动。

## 三、逐提交改动说明

### A · `32a7a2c03bf00cd51e9b304a34c94f413776c4f2`（cherry-pick -x `6308693920a4e180f74559549c2606b8539d1ba0`）

两个玻璃 helper 恒按深色模式渲染：

- `PhotoCleanupMVE/Features/S1/S1View.swift`：`s1ChromeGlassBackground(in:interactive:)` 的 `if #available(iOS 26.0, *)` 分支内、`glassEffect(...)` 调用之后追加 `.environment(\.colorScheme, .dark)`；`s1LegacyChromeGlassBackground(in:)` 收尾的 `.overlay { ... }`（描边）之后追加同一覆盖。
- `PhotoCleanupMVE/Features/S2/S2View.swift`：`s2ChromeGlassBackground`／`s2LegacyChromeGlassBackground` 同构两处。
- 计数变化（剔注释）：`S1View.swift`／`S2View.swift` 的 `colorScheme, .dark)` 各 0→2；其余全部既有 needle 计数不变。

### B · `1d88203a1fc37389c745f3aa8e434cce738ef04b`（cherry-pick -x `e89b95a248e6bc47224c4c7c3929b196b3219794`）

五个玻璃容器恒按深色模式渲染：

- `S1View.swift`：`chromeBar`（`GlassEffectContainer { chromeItems(model) }`）、`s1GlassBadgeOverlay`、`s1GlassBadgeHost` 三处容器链尾各加 `.environment(\.colorScheme, .dark)`。
- `S2View.swift`：`topBar`、`actionBar` 两处容器链尾同上。
- 计数变化：`colorScheme, .dark)` S1View 2→5、S2View 2→4；其余不变。

### C · `bc9552277c072eb5d7aafcdd0d37af347009e269`（cherry-pick -x `df10428b74d3e0547dcbe4a30a8623dd14cc236b`）

四处系统材质恒按深色模式渲染：

- `S1View.swift`：写回失败 toast（`.background(.regularMaterial, in: Capsule())` 之后）、排序／分组下拉菜单 `menuContainer` 收尾（`.shadow(...)` 之后）各加覆盖。
- `S2View.swift`：写回失败 toast、相簿 sheet 教程提示条（`.background(.ultraThinMaterial, in: Capsule())` 之后）各加覆盖。
- 计数变化：`colorScheme, .dark)` S1View 5→7、S2View 4→6；`.background(.regularMaterial)`（无 `in:`，S2 标定面板，不纳入）仍 3；其余不变。

### D · `bd4e213d22d5bcd0723347b27aa2e4a89c97c46f`（cherry-pick -n `a01ffe616396750a091c8d22dd8497d9f4983922` + `cp` 覆盖为 v3 + 提交）

- 新增 `PhotoCleanupMVETests/IC172GlassAlwaysDarkTests.swift`（448 行，7 条测试，blob `c8cb6d6e0976bdd84d0dcf5816e20b3320a925e2`）。
- `PhotoCleanupMVE.xcodeproj/project.pbxproj`：登记该测试文件，新增 `fileRef 100000000000000000000075`（3 处）、`buildFile 200000000000000000000072`（2 处），定义行无撞号。
- **与 v1（IC-172 D，`b49a40de20a2790da747428bce3ae423d316e20d`）的差异**：`testIC172A_S1LegacyRecipeIsDarkInBothStyles` 改名为 `testIC172A_S1LegacyRecipeIgnoresInterfaceStyle`，删除了原来拿裸材质／手写中心层拷贝当参照的第二条断言，只保留"两侧相同"（≤ 3）；新增 `testIC172C_MaterialRecipesUnderOverrideAreSystemDark`（toast／教程提示条／S1 菜单三组"同棵树只差一个覆盖修饰符"的正确参照）与私有 helper `assertOverride(_:matchesDarkOf:_:file:line:)`；其余五条测试与全部取样／扫描 helper 逐字节相同。

### merge · `39dc8d0be448ea051f37fdb99be8dbae3d35ca35`

`git merge --no-ff feature/ic-174-glass-always-dark-reissue`，父提交 `467fe74a0323c98e938142a2107f16843d21cc96`（合并前 main）与 `bd4e213d22d5bcd0723347b27aa2e4a89c97c46f`（分支 tip）。首行：

```
merge(IC-174): 玻璃一律按系统深色模式的效果（IC-172 重发：两个 helper、五个容器、四处系统材质）
```

## 四、占位值登记

本卡不涉及 `S2CalibrationConfiguration` 出厂值变更，`schemaVersion` 仍 7，无需递增。

## 五、测试项数变化

892（IC-171 合并后基线）→ 899（+7，v3 新增 7 条测试）。CI 两次运行（#353、#354）均实测 `Executed 899 tests, 0 failing test case(s)`。

## 六、本地门禁退出码（四个提交各一次）

| 子项 | selfcheck.ps1 | scan-hardcoded-user-visible-strings.ps1 | git diff --check |
|---|---|---|---|
| A | 0 | 0 | 0 |
| B | 0 | 0 | 0 |
| C | 0 | 0 | 0 |
| D | 0 | 0 | 0 |

## 七、40 位 SHA 核验命令与结果（`git cat-file -e <sha>^{<类型>}`，全部退出码 0）

```
$ git cat-file -e 467fe74a0323c98e938142a2107f16843d21cc96^{commit}   → exit 0
$ git cat-file -e e356aeda17da53a064892e04f39bea1032f5bf8d^{commit}   → exit 0
$ git cat-file -e 6308693920a4e180f74559549c2606b8539d1ba0^{commit}   → exit 0
$ git cat-file -e e89b95a248e6bc47224c4c7c3929b196b3219794^{commit}   → exit 0
$ git cat-file -e df10428b74d3e0547dcbe4a30a8623dd14cc236b^{commit}   → exit 0
$ git cat-file -e a01ffe616396750a091c8d22dd8497d9f4983922^{commit}   → exit 0
$ git cat-file -e 32a7a2c03bf00cd51e9b304a34c94f413776c4f2^{commit}   → exit 0
$ git cat-file -e 1d88203a1fc37389c745f3aa8e434cce738ef04b^{commit}   → exit 0
$ git cat-file -e bc9552277c072eb5d7aafcdd0d37af347009e269^{commit}   → exit 0
$ git cat-file -e bd4e213d22d5bcd0723347b27aa2e4a89c97c46f^{commit}   → exit 0
$ git cat-file -e 39dc8d0be448ea051f37fdb99be8dbae3d35ca35^{commit}   → exit 0
$ git cat-file -e 3cf48335bdf1153f5f349e985fce3f5c2abefa29^{commit}   → exit 0
$ git cat-file -e 571a5efa4b51a82d859d415e397dec0628b772e5^{commit}   → exit 0
$ git cat-file -e 833e74cea6524ac5c5f860ae50d71656f54ec457^{commit}   → exit 0
$ git cat-file -e c8cb6d6e0976bdd84d0dcf5816e20b3320a925e2^{blob}     → exit 0
$ git cat-file -e b49a40de20a2790da747428bce3ae423d316e20d^{blob}     → exit 0
$ git cat-file -e 82a688a03b3a364cefb55b305bbc778b625b3027^{blob}     → exit 0
$ git cat-file -e 900380bbb6387bc3059ca31b0501904b03ff201d^{blob}     → exit 0
$ git cat-file -e 349ab69d6832e05311b060830dcc1f1757faeeb3^{blob}     → exit 0
$ git cat-file -e 540c3b3a49d8dd01eaff29293d6c353fdc8e8160^{blob}     → exit 0
$ git cat-file -e 99dd6a9ba1170c3b3dcedc26fec2e22850912eb3^{blob}     → exit 0
$ git cat-file -e bea3bf09887428db76827877408a27b09ecf0bb3^{blob}     → exit 0
```

全部 22 个 40 位 SHA（14 commit + 8 blob）核验通过，退出码均为 0。
