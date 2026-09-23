# IC-165 自验报告（「卡片叠」首页与新类别页搬成正式，旧首页与旧类别页退役）

## 一、结论（先行）

四个子项 A → B → C → D 各自独立提交，另有**一个补正提交 C′**，均已合并进 `main` 并推送。

- A `b6b8464`、B `5e96814`、C `4b6929c`、D `c7466fb`、C′ `dc7e494`
- 合并提交 **`096fb08695972acafed660a9fc1423e3006d4245`**（`--no-ff`，首行照卡面）

**CI 预算 3 次，用满 3 次**：

| 运行 | 被测提交 | 结果 |
|---|---|---|
| #330 | A | 绿，865 项 0 失败 |
| #331 | D | **红**，865 项 1 失败 |
| #332 | C′ | 绿，865 项 0 失败 |

合并后 `main` 自动运行 **#333**：一次绿，865 项 0 失败，真实退出码 0（G931）。**Lynn 装的包是 #333 的 artifact `PhotoCleanupMVE-unsigned-096fb0869597`（id 10743329110）。**

**#331 那一条红是执行端缺陷，不是卡面缺陷**（第八节）：
- 红的是 C 里我改写的 `testIC147CAssertion11EveryS0StringGoesThroughTheCatalog`。
- 期望值写成数组字面量，`Set.filter` 因此解析为返回数组的重载，四条借用 key 的比较顺序跟着集合迭代顺序走、每个进程随机。
- 卡不授权 amend，另起 C′ 只把期望值改成 `Set([…])`。
- 产品零改动，项数不变。

闸门：

| 闸门 | 结果 | 要点 |
|---|---|---|
| G926 搬运保真 | 通过 | 八个文件 blob 与 `562f8b7` 逐一相同；类别页 + Zoom 拼接 `diff` 为空；A 的 CI #330 865／0 |
| G927 白名单外零改动 | 通过 | 十五个被保护目录／文件对象两侧相同；`schemaVersion` 7、`cacheSchemaVersion` 1；十二条被保护分支 tip 未变 |
| G928 计数 | 通过 | 第四节表、子项 B 第 1／2 条、子项 D 六条逐条实测相符（第七节）；`case .failed:` 一处卡面措辞按 Lynn 裁定解读（第九节） |
| G929 CI | 通过 | 以分支 tip C′ 的 #332 为准：865／0，退出码 0，`OS:26.2, name:iPhone 16`，`testIC063` passed 且 build 行在 `IC063_WARMUP_GATE_END` 之前 |
| G930 合并前置 | 通过 | 工作树净，`git ls-remote origin refs/heads/main` 仍 `fbee8b1` |
| G931 合并后运行 | 通过 | #333 865／0，退出码 0；artifact `PhotoCleanupMVE-unsigned-096fb0869597`，id 10743329110，有效期至 2026-12-22T10:03:10Z |

- **与 v3 的三处暂时偏离**照裁定 一登记（第十一节）。
- **H84 七条**留给 Lynn 装 #333 产物判（第十二节），执行端不代为下结论。
- **报告提交方式**：按卡面授权（惯例 44），合并与 #333 之后直接在 `main` 上追加恰一个 docs 提交，只含 `Reports/IC-165/` 两个文件，按 `paths-ignore` 不触发 CI。

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260923-165-deck-formal.md` |
| 规格 | SPEC-S0 v3，SHA-256 `F52FC2C1381949DDFE86BDE476A103BA3476EEBDA0BD77B5D2669BA2D0EF83F6` |
| 继承提交 | `main` = `fbee8b1e24815f248fd67bcc02d59b64eea72dad`（IC-164 docs；其父为合并提交 `243e3ad666bea8471ddb6c032e188dc34cc9c374`） |
| 来源提交 | `562f8b7afa14508e3efebbd57e980e275946ab95`（`probe/ic-163-deck-home-preview-r2` tip；`git cat-file -t` = `commit`） |
| 目标分支 | `feature/ic-165-deck-formal`（reflog：`fbee8b1 … branch: Created from main`，01:24:24 -0700，早于 A 提交 01:26:51） |
| 范围边界 | 卡面白名单（A～D 四行 + `Reports/IC-165/`）；IC-166 的四件事、`Core/`、`Services/`、`App/`、SPEC、Decision_log、探针与冻结分支一律未动 |

## 三、开工四步

1. `git status --porcelain` 为空；工作树在 `main`（上一卡 IC-164 的 docs 提交 `fbee8b1` 之后）。
2. `git merge-base --is-ancestor 243e3ad666bea8471ddb6c032e188dc34cc9c374 main` 退出码 0（写报告时对 `fbee8b1` 复跑，仍为 0）。
3. `git ls-remote origin refs/heads/main` = `fbee8b1…2dad`，与本地一致。
4. **先切分支再改文件**：`git switch -c feature/ic-165-deck-formal`。reflog 证实分支建于 `fbee8b1`，建立时刻早于第一个改动提交。

第 1～3 步的原始命令输出留在本会话前段，未单独存档；第 2 步与分支建立点已在写报告时复核。

## 四、提交链与本地门禁

| 序 | 提交（完整 SHA） | 内容 |
|---|---|---|
| A | `b6b8464f7de1998173140cdbc816c37dcaefc909` | 先加新，与 #327 同形态 |
| B | `5e968143822983d6f5ad00f77f44d8a04c3cd474` | 接线切换 + 三处缺口 + 纪律修正 |
| C | `4b6929c89c0578375106eedef858a910a9191788` | 共享符号搬家 + 退役 + 改名 + 九份测试 |
| D | `c7466fb371d9e23d1ffc39b81a21b125230a7a85` | 新断言六条 |
| C′ | `dc7e49459f15fb6227c3f34903357ae490aaa7ed` | IC147 断言 11 期望值改 `Set`（#331 红的补正） |
| 合并 | `096fb08695972acafed660a9fc1423e3006d4245` | 父 1 `fbee8b1`、父 2 `dc7e494`；合并树 `7b8d2b24940be51716d9c605a8b284eb9a191270` = `dc7e494` 的树 |

### 本地三道门禁

在 scratchpad 克隆里对每个提交 `checkout --detach` 后逐一复跑：`selfcheck.ps1`、`scan-hardcoded-user-visible-strings.ps1`、`git diff --check <提交>^ <提交>`。表中数字为 PowerShell `$LASTEXITCODE`。每个提交当时在主仓库也跑过一遍，结果相同。

| 提交 | 工作树 | selfcheck | 扫描器 | diff --check | 扫描器读数 |
|---|---|---|---|---|---|
| A | 净 | 0 | 0 | 0 | 目录条目 264 = 产品源码引用 key 264，残留 0 |
| B | 净 | 0 | 0 | 0 | 264 = 264，残留 0 |
| C | 净 | 0 | 0 | 0 | 254 = 254，残留 0 |
| D | 净 | 0 | 0 | 0 | 254 = 254，残留 0；needle 交叉审计扫 46 个测试文件 |
| C′ | 净 | 0 | 0 | 0 | 254 = 254，残留 0 |

selfcheck 末行五次都是「结构自验通过：……不少于 189 项测试的数量门禁均符合要求」。

## 五、闸门逐条

### G926（搬运保真，子项 A）

A 提交里八个文件的 blob 与 `562f8b7` 逐一比对：

| 本卡路径（A 提交） | blob | `562f8b7` 路径 | blob | 判定 |
|---|---|---|---|---|
| `Features/S0/S0DeckMetrics.swift` | `541070cf03a039fddf14560b119b5da5a7c93b92` | 同名 | `541070cf03a039fddf14560b119b5da5a7c93b92` | 相同 |
| `Features/S0/S0DeckHomeModel.swift` | `579f40df2d2f973aadc5216b3880539b21ac31c4` | 同名 | `579f40df2d2f973aadc5216b3880539b21ac31c4` | 相同 |
| `Features/S0/S0DeckHomeView.swift` | `42213bd2eb6774ddb826f2ff2150850150eebe6c` | 同名 | `42213bd2eb6774ddb826f2ff2150850150eebe6c` | 相同 |
| `Features/Shared/S0DeckCoverView.swift` | `6a5c321e06e5b1b33908b19623e11294f05174a1` | `Features/S0/S0DeckCoverView.swift` | `6a5c321e06e5b1b33908b19623e11294f05174a1` | 相同 |
| `Features/Shared/S0DeckAssetDates.swift` | `bea428d8974ad233476f6cb8ceedb315449ec5db` | `Features/S0/S0DeckAssetDates.swift` | `bea428d8974ad233476f6cb8ceedb315449ec5db` | 相同 |
| `PhotoCleanupMVETests/IC162DeckPreviewTests.swift` | `ccf23fcd3eeef3996b18cdc833af058d7af1f1e8` | 同名 | `ccf23fcd3eeef3996b18cdc833af058d7af1f1e8` | 相同 |
| `PhotoCleanupMVETests/IC163DeckPreviewRoundTwoTests.swift` | `adaa2e10700afc84ec6c6d0c986c17908769f804` | 同名 | `adaa2e10700afc84ec6c6d0c986c17908769f804` | 相同 |
| `Features/S0/S0CleanupFlowView.swift` | `f1d49b69bf8d019578a92e5204c4714c08cf6dfa` | 同名 | `f1d49b69bf8d019578a92e5204c4714c08cf6dfa` | 相同 |

（前缀 `PhotoCleanupMVE/` 省略。）

**拼接 diff**：

```
$ diff <(git show 562f8b7:…/S0DeckCategoryPageView.swift) \
       <(cat <(git show b6b8464:…/S0DeckCategoryPageView.swift) <(echo) <(git show b6b8464:…/S0DeckZoomTransition.swift | tail -n 29))
diff exit=0
```

- 新页面文件 955 行，末行 `}`，blob `e126f0e1fc712f9acc4c01b2d91e0dcf846c9aea`。
- Zoom 文件 32 行：文件头 `// IC-165 A（裁定 五）：…` + `import SwiftUI` + 空行 + 29 行，blob `c1424f9166525d4b5d72f60f745df38a5ee340c3`。
- 预览页面 blob `c8047dc5ce08ac727a8e958f1ee734f14404fefe`。

**IC163 测试文件**：`git diff fbee8b1 <提交> -- PhotoCleanupMVETests/IC163DeckPreviewRoundTwoTests.swift` 只有一个 hunk `@@ -247,4 +247,124 @@`。
- :1-249 两侧 `diff` 为空。
- :250 在 `main` 是 `}`、在本卡是空行，与卡面事实基础一致。

**A 的 CI**：#330 865／0，见第五节 G929 的运行表。

### G927（白名单外零改动）

`git diff --name-only fbee8b1 096fb08` 共 32 个路径，全部在卡面白名单内（逐文件见 change-list 第二节）。

被保护对象两侧逐一比对（`fbee8b1` vs 合并提交 `096fb08`；分支 tip `c7466fb`／`dc7e494` 同样全部相同）：

| 路径 | 类型 | 对象（两侧相同） |
|---|---|---|
| `PhotoCleanupMVE/App` | tree | `a8ae7e545b8b8809f300c5ba47081c16c84c51e0` |
| `PhotoCleanupMVE/Core` | tree | `86fe9d4b2955830c9e4c1407cb69b7aaba5a7b5a` |
| `PhotoCleanupMVE/Services` | tree | `922e91638d2b4564b8e4061e0270f44b28f114e7` |
| `PhotoCleanupMVE/Features/S1` | tree | `5bb26f016d35fb1327fccef002da4e7c1921eec1` |
| `PhotoCleanupMVE/Features/S2` | tree | `f43aa47cafbecac163209e90c38a7adfd0b4fafe` |
| `PhotoCleanupMVE/Features/S3` | tree | `175b165b22c7a7e7c70dd6fdcb28e9afd58fca55` |
| `PhotoCleanupMVE/Features/S4` | tree | `d6bce474b5e07285a379ad4dcebe59c1bde69d81` |
| `PhotoCleanupMVE/Features/S5` | tree | `d738ec8e91342012ab2e9b415e76949b8bc33f05` |
| `PhotoCleanupMVE/Features/Shared/ThumbnailView.swift` | blob | `f506bf53dbfc8190ec052bde9a35a4a99f574657` |
| `PhotoCleanupMVE/Features/S0/S0TabContainer.swift` | blob | `9a80395451f031f86e30873917f003c63c10c6c3` |
| `.github` | tree | `74088388c62a10eb277921ecf74e766a2d407e80` |
| `Scripts` | tree | `514886dc0afc4083237c976c0f7be6ce597c50a8` |
| `PhotoCleanupMVETests/IC152DiagnosticPathTests.swift` | blob | `e9a605b039aa558ef18d548a1a13ff99cee13533` |
| `PhotoCleanupMVE/Assets.xcassets` | tree | `62cdbafc8b45291bf80fe22a2550934c91a39691` |
| `PhotoCleanupMVE/Info.plist` | blob | `f5616d84aef4fa537388cf02a372949259e6b6a3` |

- `S2Calibration.swift` 在 `Features/S2/` 树内（树相同）：`static let schemaVersion = 7` 恰 1 行。
- `Services/S0ScanRules.swift:22`：`static let cacheSchemaVersion = 1`。
- IC163 测试文件 :1-249 两侧相同（见 G926）。

**十二条被保护分支 + IC-164 分支**（`git ls-remote origin 'refs/heads/*'`，合并前实读）：

| 分支 | tip | 卡面 |
|---|---|---|
| `probe/ic-067-screenshot-subtype` | `9db02b93eccbb87d126602901807e70823535111` | `9db02b9` ✓ |
| `probe/ic-125-sentinel-negative` | `402cb6e52a11dc89ce2a8351b47314a5fe9185b8` | `402cb6e` ✓ |
| `probe/ic-137-media-playback` | `486bcb769b59eb1146c5a231c7998847206777cc` | `486bcb7` ✓ |
| `probe/ic-145-scan-service` | `d373afc7125104c01acfc296829229090e6871ce` | `d373afc` ✓ |
| `probe/ic-161-similar-photos` | `1f8ff9248e312cd4a04faec559ea9f34540b1379` | `1f8ff92` ✓ |
| `probe/ic-162-deck-home-preview` | `180b052edf24f168712c6e58754c60b88b342175` | `180b052` ✓ |
| `probe/ic-163-deck-home-preview-r2` | `562f8b7afa14508e3efebbd57e980e275946ab95` | `562f8b7` ✓ |
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` | `b368a6c` ✓ |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | `6736f1e` ✓ |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` | `a7cc1ec` ✓ |
| `feature/ic-158-diagnostic-progress-clamp` | `5cb67332437a446d98733ddc942e2905392d2891` | `5cb6733` ✓ |
| `feature/ic-164-pick-ic163-a-d` | `cc85fa4a7cfa272092a3acfade432d13de7e4e0b` | `cc85fa4` ✓ |

合并之后的复核见第十四节。

### G928（计数）

第四节表与子项 B、D 的逐条实测见第七节。汇总：

| 项 | 卡面 | 实测 |
|---|---|---|
| `enum S0DeckMetrics` 内 `static let` | 198 | 198 |
| `enum S0DeckSymbol` | 8 | 8（`chevron`、`back`、`play`、`check`、`trash`、`sort`、`percentSign`、`account`） |
| 目录条目 | 254 | 254 |
| `s0.` | 39 | 39 |
| `s0.categoryPage.` | 9 | 9 |
| `deck.` | 0 | 0 |
| `Features/S0/*.swift` 剔注释后 `import Photos`／`PHAsset`／`PHImageManager`／`PHCachingImageManager`／`PHFetch` | 各 0 | 各 0（12 个文件） |

**pbxproj 撞号扫描**：`grep -oE '^\s*[12]0000[0-9A-F]+ /\*.*\*/ = \{isa' | sort | uniq -d` 的 Python 等价实现扫出定义行 203 条，重复 0 条。

**新登记 id 逐个计数**（fileRef 应 3、buildFile 应 2）：

| 文件 | fileRef | 次数 | buildFile | 次数 |
|---|---|---|---|---|
| `S0DeckMetrics.swift` | `100000000000000000000062` | 3 | `20000000000000000000005F` | 2 |
| `S0DeckHomeModel.swift` | `100000000000000000000063` | 3 | `200000000000000000000060` | 2 |
| `S0DeckCoverView.swift` | `100000000000000000000064` | 3 | `200000000000000000000061` | 2 |
| `S0DeckHomeView.swift` | `100000000000000000000065` | 3 | `200000000000000000000062` | 2 |
| `IC162DeckPreviewTests.swift` | `100000000000000000000066` | 3 | `200000000000000000000063` | 2 |
| `S0DeckCategoryPageView.swift` | `100000000000000000000067` | 3 | `200000000000000000000064` | 2 |
| `S0DeckAssetDates.swift` | `100000000000000000000069` | 3 | `200000000000000000000066` | 2 |
| `S0DeckZoomTransition.swift` | `10000000000000000000006A` | 3 | `200000000000000000000067` | 2 |
| `S0CleanupDataProviding.swift` | `10000000000000000000006B` | 3 | `200000000000000000000068` | 2 |
| `S0Text.swift` | `10000000000000000000006C` | 3 | `200000000000000000000069` | 2 |
| `S0CategoryPageSelection.swift` | `10000000000000000000006D` | 3 | `20000000000000000000006A` | 2 |
| `IC165DeckFormalTests.swift` | `10000000000000000000006E` | 3 | `20000000000000000000006B` | 2 |
| `S0SegmentBarModel.swift`（改名，id 保留） | `10000000000000000000004D` | 3 | `20000000000000000000004A` | 2 |

**退役 id 删净**：

| 文件 | fileRef | 次数 | buildFile | 次数 | 文件名出现次数 |
|---|---|---|---|---|---|
| `S0View.swift` | `100000000000000000000049` | 0 | `200000000000000000000046` | 0 | 0 |
| `S0HomeMetrics.swift` | `10000000000000000000004C` | 0 | `200000000000000000000049` | 0 | 0 |
| `S0CategoryRow.swift` | `10000000000000000000004E` | 0 | `20000000000000000000004B` | 0 | 0 |
| `S0CategoryPageMetrics.swift` | `10000000000000000000005B` | 0 | `200000000000000000000058` | 0 | 0 |
| `S0CategoryPageView.swift` | `10000000000000000000005D` | 0 | `20000000000000000000005A` | 0 | 0 |
| `S0SegmentBar.swift`（旧名） | — | — | — | — | 0 |

**分组**：
- Shared group children = `ThumbnailView.swift`、`S0DeckCoverView.swift`、`S0DeckAssetDates.swift`。
- S0 group children = 12 个 `Features/S0/` 文件，与磁盘一致。
- 改后最大号：fileRef `…6E`、buildFile `…6B`。
- 登记前各重扫一次最大号：C 前为 `…6A／…67`，D 前为 `…6D／…6A`。

### G929（CI）

**运行表**：

| 项 | #330（A） | #331（D） | #332（C′，分支 tip） |
|---|---|---|---|
| run id | 35837199126 | 35842546410 | 35843642348 |
| 被测提交 | `b6b8464f7de1998173140cdbc816c37dcaefc909` | `c7466fb371d9e23d1ffc39b81a21b125230a7a85` | `dc7e49459f15fb6227c3f34903357ae490aaa7ed` |
| 结论 | success | **failure** | success |
| 「运行 XCTest」步骤 | success | failure（「构建未签名应用」「上传」两步 skipped） | success |
| 执行摘要 notice | `Executed 865 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 865 tests / 0 failures` | `Executed 865 tests, 1 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 865 tests / 1 failures` | `Executed 865 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 865 tests / 0 failures` |
| 唯一 Test Case 行（剔 `##[` 与 `[36;1m` 回显） | 865 passed / 0 failed | 864 passed / 1 failed | 865 passed / 0 failed |
| 真实退出码 | 0（`** TEST SUCCEEDED **`） | 65（注解 `Process completed with exit code 65.`，`** TEST FAILED **`） | 0（`** TEST SUCCEEDED **`） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` | 同左 | 同左 |
| 分段耗时 notice | `模拟器启动 75 s；xcodebuild test 255 s；总 330 s` | `模拟器启动 72 s；xcodebuild test 369 s；总 441 s` | `模拟器启动 71 s；xcodebuild test 221 s；总 292 s` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1905410，SHA-256=0c8d4f806e46b330f16e40f03dbb926e3094081c520dde26806877efbe34b677` | 无（构建步骤 skipped） | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1788110，SHA-256=75c70180680ad48aa8ebae3a211a7a16c90d029af87f1b8a5c7bd84be817dbfc` |
| artifact | `PhotoCleanupMVE-unsigned-b6b8464f7de1`，id 10739783503，1905580 B，有效期至 2026-12-22T08:27:12Z | 无 | `PhotoCleanupMVE-unsigned-dc7e49459f15`，id 10743160031，1788280 B，有效期至 2026-12-22T09:33:30Z |
| `testIC063` | passed（6.268 s）；build 行 `building pipeline path_exterior-jba6la8feba4 took 0.710775 seconds` 在日志第 2485 行，`IC063_WARMUP_GATE_BEGIN` 2486、`END` 2490 | passed（7.261 s）；build 行 0.780949 s 在 2572，`END` 2576 | passed（6.258 s）；build 行 0.510446 s 在 2533，`END` 2537 |

（行号为剔回显后逐步日志的行序号；三次都有 `IC063_DIAGNOSTICS_SAMPLE_BEGIN` 且其后「采样总数：15」。）

**#331 唯一失败**（注解原文）：

```
IC147S0BehaviorTests.swift:867: error: -[PhotoCleanupMVETests.IC147S0BehaviorTests testIC147CAssertion11EveryS0StringGoesThroughTheCatalog] : XCTAssertEqual failed: ("["s1.sort.accessibility", "s1.limited.banner", "s1.sort.oldest_first", "s1.sort.newest_first"]") is not equal to ("["s1.limited.banner", "s1.sort.accessibility", "s1.sort.newest_first", "s1.sort.oldest_first"]")
```

**IPA 字节数变化**：A 1905410 → C′ 1788110，少 117300 B。③ 推测是 C 删了五个旧页面文件、编译产物变小；未逐段验证。

**各族逐条（#332）**：

| 族 | passed | failed |
|---|---|---|
| IC147S0BehaviorTests | 16 | 0 |
| IC148S0VisualTests | 12 | 0 |
| IC151AmbientFixedColorTests | 7 | 0 |
| IC153ScanServiceTests | 13 | 0 |
| IC155CategoryDataAndCoverTests | 8 | 0 |
| IC156CategoryPageTests | 9 | 0 |
| IC157LongPressIntoS2Tests | 8 | 0 |
| IC160SelectionSurvivesS2Tests | 4 | 0 |
| IC162DeckPreviewTests | 3 | 0 |
| IC163DeckPreviewRoundTwoTests | 6 | 0 |
| IC165DeckFormalTests | 6 | 0 |
| IC152DiagnosticPathTests（未改，对照） | 6 | 0 |

#331 里除 IC147 断言 11 以外各族同样全过，IC165 六条 6／0。

### G930（合并前置）

- G926～G929 满足（G929 以分支 tip C′ 的 #332 为准）。
- `git status --porcelain` 为空。
- `git ls-remote origin refs/heads/main refs/heads/feature/ic-165-deck-formal`：`main` = `fbee8b1e24815f248fd67bcc02d59b64eea72dad`，分支 = `dc7e49459f15fb6227c3f34903357ae490aaa7ed`。

**合并过程**：
- `git switch main`，然后 `git merge --no-ff feature/ic-165-deck-formal -F <消息文件>`，退出码 0（ort 策略，无冲突）。
- 第一次写成 `-F -`，git 报 `could not read file '-'`、退出码 129，未产生任何提交，`HEAD` 仍 `fbee8b1`；改用 scratchpad 里的消息文件重跑成功。
- `git push origin main` 直连成功：`fbee8b1..096fb08  main -> main`。
- 未遇到 `[Merge Without Review]` 拒绝。

### G931（合并后 `main` 运行）

| 项 | #333 |
|---|---|
| run id | 35846532926（`event` = push，`head_branch` = `main`，attempt 1） |
| 被测提交 | `096fb08695972acafed660a9fc1423e3006d4245`（合并提交） |
| 结论 | success；十二步全部 success |
| 执行摘要 notice | `Executed 865 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 865 tests / 0 failures` |
| 唯一 Test Case 行 | 865 passed / 0 failed；IC147 16、IC148 12、IC151 7、IC153 13、IC155 8、IC156 9、IC157 8、IC160 4、IC162 3、IC163 6、IC165 6，全部 0 失败 |
| 真实退出码 | 0（`** TEST SUCCEEDED **`） |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` |
| 分段耗时 notice | `模拟器启动 96 s；xcodebuild test 365 s；总 463 s` |
| IPA 校验 notice | `文件=PhotoCleanupMVE-unsigned.ipa，字节数=1788110，SHA-256=48f4a8e0d1d949e4cd396e684e72a32f3b46642b261414de0ff6699060add7d7` |
| **artifact（Lynn 装这个）** | **`PhotoCleanupMVE-unsigned-096fb0869597`**，id **10743329110**，1788280 B，创建 2026-09-23T10:14:04Z，**有效期至 2026-12-22T10:03:10Z**，digest `sha256:5fa71f900fc06ad44a7bd014c0e6322c7c2e9a8a385ef31e7507e897c8ce3b2d` |
| `testIC063` | passed（6.931 s）；build 行 `building pipeline path_exterior-jba6la8feba4 took 0.614862 seconds` 在日志第 2499 行，`IC063_WARMUP_GATE_BEGIN` 2500、`END` 2504 |

**IPA 可复现性（②）**：#332 与 #333 的源码树相同（`7b8d2b2`），IPA 字节数都是 1788110，但 SHA-256 不同（`75c70180…` vs `48f4a8e0…`）。③ 推测是构建产物带时间戳一类的非确定内容；未拆包验证。

## 六、子项 D 六条新断言（`PhotoCleanupMVETests/IC165DeckFormalTests.swift`）

| # | 测试函数 | 钉住什么 | #332 |
|---|---|---|---|
| 1 | `testIC165A_FeaturesS0IsPhotoKitFreeAtDirectoryLevel` | `Features/S0/` 全部 `.swift`（`FileManager` 枚举，实测 12 个，≥ 10）剔注释后五个 PhotoKit needle 各 0；正对照 CoverView `PHImageManager` 2、AssetDates `PHAsset` 1 | passed |
| 2 | `testIC165A_AvailabilityCheckLivesOnlyInZoomTransitionFile` | `Features/S0/` + `Features/Shared/S0Deck*` 里 `#available` 只在 Zoom 文件且恰 2；首页与类别页文件级裸数 ⊆ {0,1,2}（提取器照 IC156） | passed |
| 3 | `testIC165A_CoverViewFramesThenClipsAndOwnsHitShape` | CoverView `scaledToFill()` 1、`.clipped()` 1、`.contentShape(` 1、`isNetworkAccessAllowed = false` 1，`.frame(` 索引在 `.clipped()` 之前 | passed |
| 4 | `testIC165B_HomeCarriesBannerScanningHeroAndVerificationReadouts` | 首页：代码类 `S1LimitedBannerStyle.` 4（≥ 3）、`cleanableByteCount` 0、`libraryTotalByteCount == 0` 1、`machine.beginVerification` 1、`switch machine.state {` 1、`content` 分派段内 `case .empty:`／`case .failed:` 各 1（第九节）、`machine.showsCategoryRows` 0、`withAnimation(` 1 且切片含两个 expand 值、`S2AmbientBackdropView`／`Material`／`ultraThin`／`colorScheme`／`S0HomePalette`／`s0GlassSurface` 0；key 类（原文）`s1.limited.banner`／`s0.home.hero.scanning`／`s0.home.pending.checking`／`passed`／`failed` 各 1、`Text("` 0 | passed |
| 5 | `testIC165C_CategoryPageKeysAndChromeDiscipline` | 类别页：原文 `s0.categoryPage.back` 2、`subtitle` 1、`sort.size` 2、`s1.sort.newest_first` 2、`oldest_first` 2、`s1.sort.accessibility` 2、`deck.` 0、`Text("` 0；剔注释 `S2OverlayLayout` 0、`S0DeckMetrics.toast` 5、`gridCheckGlyphFontSize` 1、`compactNavBackSide` 4（≥ 3）、`S1ChromeLayout.rowHeight` 2、`LongPressGesture()` 1、`.simultaneousGesture(` 1、`Button {` 3、`s1ChromeGlassBackground(` 5、`Material`／`ultraThin`／`#available` 0 | passed |
| 6 | `testIC165C_RetirementAndRegistryCounts` | 五个退役文件磁盘不存在、pbxproj 文件名 0；七个旧类型 needle 在产品源码剔注释后各 0；`S0SegmentBarModel.swift` 存在且 `struct S0SegmentBarView` 0；198／8；目录 39／9／0、九条删去的 key 各 0、`s0.category.rest` = 「其余照片」、`s0.home.hero.label` = 「可清理的空间」；跨前缀借用集（`Features/S0/*.swift` + `Features/Shared/S0Deck*.swift` 原文，`localizationKeys(in:)`）恰 = 四条 `s1.*` | passed |

- 夹具照 IC157 末段：`sourceText`／`strippedSource`／`occurrences`／`slice`，外加 `numericLiterals`、`localizationKeys`、`loadCatalogValues`、`swiftFiles(inDirectory:recursive:)`。
- 断言 6 的借用集比较，`borrowed` 声明为 `Set<String>`，期望的数组字面量随之推断为 `Set`，与顺序无关。
- 六条只扫源码与目录，不构造视图、不碰 PhotoKit。

## 七、第四节表与子项 B／D：卡面／实测

### 口径与复核方法

- 代码类 needle 扫剔 `//` 注释与字符串内容的源码。
- key 类（`s0.`／`s1.`／`deck.` 开头）扫原文。
- 实测值来自两个 Python 移植脚本：
  - `sim165.py`：移植各测试文件的 `strippedSource`／`occurrences`／`slice`／`numericLiterals`／`localizationKeys`，622 项检查、0 不符。
  - `extras165.py`：补测卡面列出而测试未钉的计数。
- 两个脚本都对 C′ 之后的工作树求值（产品源码与 D 相同）。
- CI 判定以 #332 为准。

### 子项 B 第 1 条：流程文件（剔注释）

| needle | 卡面 | 实测 |
|---|---|---|
| `S0DeckHomeView(` | 1 | 1 |
| `S0DeckCategoryPageView(` | 1 | 1 |
| `S0View(` | 0 | 0 |
| `S0CategoryPageView(` | 0 | 0 |
| `.toolbar(.hidden, for: .tabBar)` | 0 | 0 |
| `.toolbar(.hidden, for: .navigationBar)` | 1 | 1 |
| `machine.ingest(` | 3 | 3 |
| `flowModel.preservedSelection` | 2 | 2 |
| `flowModel.preservedSelection = []` | 2 | 2 |
| `= $0` | 0 | 0 |
| `@State ` | 0 | 0 |
| `@ObservedObject` | 1 | 1 |
| `@Namespace` | 1 | 1 |

### 子项 B 第 2 条：首页

**代码类（剔注释）**：

| needle | 卡面 | 实测 |
|---|---|---|
| `switch machine.state {` | 1 | 1 |
| `case .empty:` | 1 | 1 |
| `case .failed:` | 1 | **全文件 2**，`content` 分派段内 1（第九节） |
| `case .scanning, .ready:` | 1 | 1 |
| `machine.showsCategoryRows` | 0 | 0 |
| `S1LimitedBannerStyle.` | ≥ 3 | 4 |
| `libraryTotalByteCount == 0` | 1 | 1 |
| `cleanableByteCount` | 0 | 0 |
| `verificationState` | ≥ 1 | 1 |
| `machine.beginVerification` | 1 | 1 |
| `machine.handle(` | 4 | 4 |
| `machine.ingest` | 1 | 1 |
| `withAnimation(` | 1 | 1 |
| `s1ChromeGlassBackground(` | 3 | 3 |
| `S1ChromeTypography.` | 4 | 4 |
| `S0HomePalette`／`S0HomeMetrics`／`s0GlassSurface` | 0 | 0／0／0 |

**key 类（原文）**：

| needle | 卡面 | 实测 |
|---|---|---|
| `s1.limited.banner` | 1 | 1 |
| `s0.home.hero.scanning` | 1 | 1 |
| `s0.home.pending.checking` | 1 | 1 |
| `s0.home.pending.passed` | 1 | 1 |
| `s0.home.pending.failed` | 1 | 1 |

**事实基础里的首页计数（`562f8b7` → 现在）**：

| needle | 预览 | 现在 |
|---|---|---|
| `hasBootstrapped` | 3 | 3 |
| `machine.showsPendingClearanceRow` | 1 | 1 |
| `s1ChromeCircleGlass()` | 1 | 1 |
| `S1ChromeLayout.` | 9 | 11（受限提示条 +2） |
| `Image(systemName: ` | 3 | 3 |
| `Button {` | 2 | 2 |
| `onTapGesture` | 1 | 1 |
| `Material`／`colorScheme`／`.primary`／`ultraThin`／原文 `Text("` | 0 | 0 |

### 第四节表逐行

**IC147S0BehaviorTests**：

| 断言 | 项 | 卡面 | 实测 |
|---|---|---|---|
| C | 文件 | `S0DeckHomeView.swift` | 同 |
| C | `machine.showsPendingClearanceRow` | 1 | 1 |
| C | `switch machine.state {` | 1 | 1（全文件与分派段内均 1） |
| C | `case .failed:` | 1 | 分派段内 1（全文件 2，第九节） |
| C | `case .empty:` | 1 | 分派段内 1 |
| C | `case .scanning, .ready:` | 1（裁定 五） | 分派段内 1 |
| C | `hasBootstrapped` | 3 | 3 |
| 07 | 文件名 | Deck 首页 | 同；四文件 `scanState = `／`ledgerState = `／`verificationState = ` 各 0 |
| 09 | 文件名；协议行 | Deck 首页；`S0CleanupDataProviding.swift` | 同；`protocol S0CleanupDataProviding: AnyObject {` 1 |
| 10 | `s0.` | 39 | 39 |
| 10 | `s0.home.hero.label` | 「可清理的空间」 | 同 |
| 11 | 名单 | Deck 首页、Deck 类别页、`S0TabContainer`、`S0Text` | 同；引用 key 43 条（> 20） |
| 11 | `s0.` | 39 | 39；引用的 `s0.` 集合 = 目录 `s0.` 集合 |
| 11 | 借用集 | 四条 | `{s1.limited.banner, s1.sort.accessibility, s1.sort.newest_first, s1.sort.oldest_first}`（C′ 起按集合比较） |

**IC148S0VisualTests**：

| 断言 | 项 | 卡面 | 实测 |
|---|---|---|---|
| 01、12 | 退役 | 删函数 | 已删；族 14 → 12 |
| 02 | `newProductFiles` | Metrics、HomeModel、SegmentBarModel、Zoom | 同；七个动态外观 needle 各 0 |
| 02 | `viewFiles` | Home、Page、Zoom | 同 |
| 02 | 枚举 | `enum S0DeckMetrics` | ≥ 1 |
| 03 | 三个锚 | Home、Page、Cover | 三个切片都在，体内裸数 ⊆ {0,1,2}；`S0DeckMetrics.` 147／144／1 |
| 03 | 文件级裸数（两只 Deck 视图） | ⊆ {0,1,2} | 是 |
| 04 | PhotoKit 名单 = `viewFiles` | 各 0 | 各 0（外加 Metrics、TabContainer） |
| 05 | 三个锚 | `deckScreen`／`failureBlock`／`centeredBlock(` | 各 1 |
| 05 | 原文 key | `s0.home.failed.*` 四条、`s0.home.hero.empty.*` 两条各 1 | 各 1 |
| 05 | `S0SegmentBarModel.make` | 1 | 1 |
| 06 | `heroValue` 切片 | `libraryTotalByteCount == 0` ≥ 1、原文 `s0.home.hero.scanning` ≥ 1 | 1、1 |
| 06 | 全文件 `cleanableByteCount` | 0 | 0 |
| 07 | 首页四条 | ≥ 1 | `s1ChromeCircleGlass()` 1、`s1ChromeGlassBackground(` 3、`S1ChromeLayout.` 11、`S1ChromeTypography.` 4 |
| 07 | `S1LimitedBannerStyle.` | > 0 | 4 |
| 07 | 「不自造 chrome」 | `newProductFiles` 各 0 | 各 0 |
| 10 | `s0.` | 39 | 39；名单同 IC147 11 |
| 11 | 名单 | 四个非视图文件 | 同 |
| 11 | 首页计数 | — | `machine.handle(` 4、`beginVerification` 1、`ingest` 1 |
| 11 | `withAnimation(` | 1 且切片含两值 | 1，含 |
| 11 | `Timer`／`asyncAfter`／`sleep(` | 0 | 0 |
| 13 | 状态机段 | 保留 | 保留，`S0CategoryRowPresentation` 段已删 |
| 14 | 名单 | 两只 Deck 视图 + Zoom | 同；七个原文 needle 各 0 |

**IC151AmbientFixedColorTests**：

| 项 | 卡面 | 实测 |
|---|---|---|
| `D_GlassSurfaceIsTranslucentFill` | 退役 | 已删；族 8 → 7 |
| `D_S0Drops…` 五 needle | 0 | 0 |
| `S2AmbientBackdropView()` 恰 1 那条 | 删 | 已删 |
| `A_…`／`D_S0BehaviorCallSites…` 路径 | Deck 首页 | 同；`scaledToFill`／`Image(uiImage:`／`.blur(` 0；`handle(` 4、`ingest` 1、`beginVerification` 1 |

**IC153ScanServiceTests**：`C_AppWiringAndS0ViewUntouched`

| 项 | 卡面 | 实测 |
|---|---|---|
| `machine.ingest`（改扫 Deck 首页） | 1 | 1 |
| `onSnapshotDidChange`（改扫协议文件） | 1 | 1 |
| 要求行 `var onSnapshotDidChange: (() -> Void)? { get set }` | 1 | 1 |
| `PHAsset`（首页） | 0 | 0 |

**IC155CategoryDataAndCoverTests**：

| 项 | 卡面 | 实测 |
|---|---|---|
| `C_RowBuildsForAllCoverStates` | 退役 | 已删；族 9 → 8 |
| `C_CoverSlot…` | 删 S0 段、留 Shared／S3 段 | 同 |
| `B_ProtocolGainsOneRequirement` 路径 | 协议文件 | 同；`func categoryAssets(_ id: S0CategoryIdentifier) -> [S0CategoryAsset]` 1 |
| 跨文件 `S0CategorySnapshot(`（IC147／IC148） | 15／3 不变 | 15／3；`coverAssetID:` 0／0 |

**IC156CategoryPageTests**：

| 断言 | 项 | 卡面 | 实测 |
|---|---|---|---|
| A1、A2 | 退役 | 删函数 | 已删；族 11 → 9 |
| 6 | `disciplineFiles` | Deck 页 + 流程 | 同；两文件裸数 ⊆ {0,1,2}，14 个 PhotoKit／动态外观 needle 各 0，原文 `Text("` 0 |
| 6 | `S0DeckMetrics.`（类别页） | 实测数 | **153** |
| 6 | 198 名逐个引用 | 豁免恰两个 | 未引用集合 = `{cellLabelFill, pageTitleTopSpacing}` |
| 6 | 三条 0 | `ThumbnailView(`、`showsPlaceholderGlyph: false`、`S2AmbientBackdropView()` | 0／0／0 |
| 6 | `DateComponentsFormatter`（扫 `S0Text.swift`） | ≥ 1 | 1 |
| 6 | `Image(systemName: `、`Image(systemName: S0DeckSymbol.` | 7、7 | 7、7 |
| 7 | `s0.`／`s0.categoryPage.` | 39／9 | 39／9 |
| 7 | 三条新值 | 逐条 | 九条值全部相符 |
| 7 | 页面 `s0.categoryPage.` 集合 | 九条 | 九条 |
| 7 | 页面全部 key | 13 条 | 13 条（九条 + `s0.home.share` + 三条 `s1.sort.*`） |
| 7 | 占位符 | `subtitle` = `{count}`+`{order}`；`selected`／`submit` 无 `{bytes}` | 相符 |
| 7 | IC147／IC148 文件内 `S0DeckCategoryPageView.swift` | ≥ 1 | 1／4 |
| 9 | 路径 → Deck 页 | `S0ByteCountText.string(` 4（原文）、`S0CategoryPageDurationText.string(for:` 1 | 4、1；拼接 `" GB"`／`" MB"`／`":"` 0 |
| 10 | 流程（B） | `S0DeckHomeView(` 1、tabBar 0、navigationBar 1、`S0DeckCategoryPageView(` 1 | 1、0、1、1；`machine.ingest(` 3、`navigationDestination(item:` 1、`.returnedFromCategoryPage` 1 |

**IC157LongPressIntoS2Tests**：

| 断言 | 项 | 卡面 | 实测 |
|---|---|---|---|
| B4 | `Button {` | 3 | 3 |
| B4 | 原文 `s0.categoryPage.longPressHint` | 0 | 0；`pinnedRow` 切片段已删 |
| B4 | `S1ChromeTypography.titleFontSize` | 1 | 1 |
| B4 | `Image(systemName: ` | 7 | 7 |
| B4 | 裸数 | ⊆ {0,1,2} | 是；`LongPressGesture()` 1、`.simultaneousGesture(` 1、`onTapGesture`／`onLongPressGesture` 0 |
| B5 | `s0.`／`s0.categoryPage.` | 39／9 | 39／9 |
| B5 | 三条值 | `back`／`sort.size`／`undated` | 「返回」／「从大到小」／「未知日期」 |
| B5 | 四句 `39)` needle | 各 1 | IC147 两句、IC148 一句、IC156 一句，各 1 |

**IC160SelectionSurvivesS2Tests** 断言 4（子项 B）：

| 侧 | needle | 卡面 | 实测 |
|---|---|---|---|
| 页面 | `.onChange(of: selection.selected)` | 1 | 1 |
| 页面 | `.onAppear` | 1 | 1 |
| 页面 | `preselected: flowModel.preservedSelection` | 1 | 1 |
| 页面 | `onSelectionChange(` | 0 | 0 |
| 页面 | `initialSelection: Set<String> = []` | 0 | 0 |
| 页面 | `Button {` | 3 | 3 |
| 流程 | `flowModel.preservedSelection` | 2 | 2 |
| 流程 | `= $0` | 0 | 0 |
| 流程 | `= []` | 2 | 2 |
| 流程 | `initialSelection: flowModel.preservedSelection` | 0 | 0 |
| 流程 | `S0DeckCategoryPageView(` | 1 | 1 |

**IC162DeckPreviewTests**：只改 :7 注释一句；3 条 passed。

### 视觉取值节

| 项 | 卡面 | 实测 |
|---|---|---|
| `gridCheckGlyphFontSize` | 13 | 13 |
| `toastFontSize` | 15 | 15 |
| `toastHorizontalPadding` | 16 | 16 |
| `toastVerticalPadding` | 8 | 8 |
| `toastCornerRadius` | 27 | 27 |
| `toastToDockSpacing` | 8 | 8 |
| `compactNavBackSide` | 42 | 42 |
| 删去的十一个名 + `sparkle` + `S0DeckPreview`（剔注释） | 0 | 各 0 |
| `S0DeckSymbol.account` | 用 | 首页 1 |
| `S0HomeSymbol` | 0 | 0 |
| `cardOpacity` | 0 | 0 |

## 八、#331 红的归因与处置（执行端缺陷）

**①事实**：
- 唯一失败是 `IC147S0BehaviorTests.swift:867`（注解原文见 G929）。
- 两个数组内容相同、顺序不同。
- #332 在只改这一处的 C′ 上 865／0。

**机制（①源码 + ③编译器解析，下面第 4 点说明为什么定为这个机制）**：

1. `referenced` 声明为 `Set<String>`，C 里我写的比较是：

   ```swift
   XCTAssertEqual(referenced.filter { !$0.hasPrefix("s0.") }, ["s1.limited.banner", …四条…])
   ```

2. `Set` 有两个 `filter`：`Set.filter` 返回 `Set`，`Sequence.filter` 返回 `[Element]`。第二个实参是数组字面量，编译器按字面量的默认类型选了 `[String]`，于是走 `Sequence.filter`。结果数组的顺序就是集合的迭代顺序；Swift 的哈希每个进程随机播种，顺序每次运行都可能不同。
3. `main` 上这条断言只有一条借用（`["s1.limited.banner"]`），一条元素没有顺序可言，从未暴露。IC-165 把借用扩到四条后，每次运行大约只有 1/24 的概率恰好顺序一致。
4. 为什么定为这个机制：失败信息打出来的是两个内容相同、顺序不同的方括号列表。若两侧都是 `Set`，`==` 与顺序无关，不可能判不等，所以比较的一定是数组。

**C′ 的改法**：期望值写成 `Set([…])`。这时类型参数只能是 `Set<String>`，`filter` 只能解析为 `Set.filter`。另加两行注释说明原因，未改任何计数或 needle。

**扫描同类写法**：对本卡改过的全部测试文件扫描「`XCTAssertEqual` 一侧是集合、另一侧是多元素数组字面量」。只有这一处：
- IC156 断言 7 两处用 `Set(expected.keys)`，与顺序无关。
- IC148 10、IC147 11 的 `s0.` 集合都与 `catalogS0Keys`（`Set`）比较。
- IC165 断言 6 的 `borrowed` 声明为 `Set<String>`。
- 其余数组字面量比较的都是 `.map { $0.id }` 这类本来就有序的数组。

**为什么推 CI 前没抓到（②）**：
- 我的 Python 移植（`sim165.py`）与推 D 前的只读复核子代理，都把这条比较移植成集合相等，所以都判「过」。
- Python 移植只能复算计数与集合内容，复算不了 Swift 的重载解析。
- 复核子代理报告的原话是「Will fail: none」，另列了四条非失败风险：C 提交信息写 859（在 C 时点正确）、IC156 两处精确钉值偏脆、剥离器不处理 `/* */` 与 `"""`、`testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys` 名字过时。

## 九、执行中向 Lynn 提问的一处（卡内自相矛盾）

卡面对首页 `case .failed:` 的计数写法：
- 子项 B 第 2 条：代码类（剔注释）「`case .failed:` 1」。
- 子项 D 断言 4 同样写。
- IC-147 断言 C 改钉「`case .failed:` 恰 1」。

但裁定 四要求把旧首页的 `verificationRow`（`switch machine.verificationState`，含 `case .failed:`）搬进 Deck 首页，按公式正确实装后全文件必为 2。两条要求不能同时成立。

我停下来问 Lynn，她选「**把这几条钉限定在状态 `switch` 上**」（④）。实装口径：
- 全文件 `switch machine.state {` 恰 1。
- 从 `private var content: some View {` 到其后第一处 `\n    }\n` 的切片内，`case .scanning, .ready:`／`case .empty:`／`case .failed:` 各恰 1。
- IC147 断言 C 与 IC165 断言 4 同口径，两处都加了注释说明第二个 `case .failed:` 来自 `VF` 读数的 `switch`。

## 十、项数对账

| 时点 | 项数 | 依据 |
|---|---|---|
| `main` `fbee8b1` | 859 | #329（卡面事实基础） |
| A | 865 | CI #330 实测；859 + IC162 3 + IC163 C 部分 3 |
| B | 865 | 未单独跑 CI；B 不增删测试函数，本机对 `func test` 声明行计数与 A 相同（②，陷阱 22 口径，只作差值） |
| C | 859 | 未单独跑 CI；865 − 6（IC148 01／12、IC151 GlassSurface、IC155 RowBuilds、IC156 A1／A2），本机计数 859（②） |
| D | 865 | CI #331 实测 865 项（1 失败）；859 + IC165 6 |
| C′ | 865 | CI #332 实测 865／0 |
| 合并后 `main` | 865 | CI #333 实测 865／0 |

本机按提交逐个数 `func test` 声明行：`fbee8b1` 859、A 865、B 865、C 859、D 865、C′ 865。与 CI 实测的三个点（#330／#331／#332 均 865）一致。

## 十一、与 SPEC-S0 v3 的三处暂时偏离（裁定 一，归 IC-166）

1. 「其余照片」卡仍不可进入。
2. hero 大数字仍取含 `D_全部` 的 `libraryTotalByteCount`（v3 要 `LIB` 排除 `D_全部` 与账本）。
3. S0-3 判据仍按 `cleanableAssetCount == 0`（v3 要 `N_成员 = 0`）。

**v3 订正候选（裁定 四）**：扫描首帧「正在扫描…」的字号，v3 第十四节未登记。实装借 S1 标题字号 `S1ChromeTypography.titleFontSize`，代码注释已注明，请决策会话在 v3 下一版登记或另定。

## 十二、人工判定项（H84 七条，留给 Lynn，执行端不代为下结论）

装合并后 `main` 产物（#333 的 artifact，名称／id 见 G931）后真机判：

1. 首页与 #327 预览包一样：卡片叠、展开／收起、总条联动、进类别页都在；「其余照片」卡仍不可点（本卡已知偏离，IC-166 开）。
2. 受限授权下（系统「选定的照片」）：顶排下出现受限提示条，文案与「逐张整理」tab 同一句。
3. 冷启动首扫第一帧：大数字位显示「正在扫描…」而不是「0」；数字到了以后正常增长。
4. 等待清空行（若账本非空）：点「我已清空」→「正在核对…」→ 通过显示「设备可用空间 +X」／未通过显示失败句且按钮可再点。账本为空则记「未触发」。
5. 类别页：副行随排序变（「N 项 · 从大到小」「N 项 · 最新在前」「N 项 · 最旧在前」）；两处返回钮 VoiceOver 读作「返回」；「长按任一格逐张看」那行**没有**了（v3 未定前不显示）。
6. H82 第 1～8 条快过一遍（同一份 Deck 代码）。
7. 一两句总评。

**模拟器覆盖边界（①）**：三处补齐（受限提示条、扫描首帧、`VF` 三态）只有源码扫描断言钉住（IC165 断言 4、IC148 06／07），测试宿主里没有真实相册授权与扫描时序，这三条的实际显示只能靠 H84 第 2～4 条判。

## 十三、发现但未处理的问题（按纪律只报告不修）

**卡面缺口，已按卡意处理并在此登记**：

1. **`colorSimilar` 借用了要删的名**。预览里 `static let colorSimilar = sectionAction`，而 `sectionAction` 在「删十一个 v3 未登记的名」之列，照删会编译失败。处理：`colorSimilar` 改为自带同一色值 `#F59B5B`（`Color(.sRGB, red: 245.0 / 255, green: 155.0 / 255, blue: 91.0 / 255, opacity: 1)`），名字数量与色值都不变。卡面「与 v3 登记表的对账」行未提到这层依赖。
2. **IC148 02 的「类别色与 trait 无关」循环**。卡面第四节只写了 `:375-381` 的 `enum S0HomeMetrics` → `enum S0DeckMetrics`，没提同函数里逐个解析 `S0HomeMetrics.colorBigVideo／colorSimilar／colorScreenshot／colorScreenRecording／colorDuplicate` 的循环（`main` :400-406）。这五个符号随 `S0HomeMetrics.swift` 整删，不改就编译失败。处理：循环改为 v3 卡片叠的六个类别色 `S0DeckMetrics.colorVideo／colorSimilar／colorScreenshot／colorScreenRecording／colorDuplicate／colorRest`，判据（dark 与 light 两种 trait 解析同值）不变。
3. **IC156 断言 6「198 名逐个引用」的名表来源**。卡面未说从哪取 198 个名。我在测试里从 `S0DeckMetrics.swift` 剔注释后的 `enum S0DeckMetrics {` 体内逐行取 `    static let <名>`，并先断言取到恰 198 个，防止提取器空转。

**本卡范围外、原样搬过去的过时注释**（类型体连同文档注释逐字搬，按裁定 三不改）：

4. `S0CategoryPageSelection.swift:7`「全部项默认不勾选，不预勾任何项」与 IC-160 的播种路径不符（CLAUDE.md 待开重构卡已列，原在 `S0CategoryPageView.swift:5`）。
5. `S0CleanupDataProviding.swift:7`「首页只认识这三个问题」已过时（协议现有五个要求；原在 `S0View.swift:8`，同上待开重构卡）。

**其余**：

6. `S0DeckMetrics.pageTitleTopSpacing`（34）是 v3 登记值，预览未接线，全仓 0 引用；`cellLabelFill` 同为 0 引用（v3 未定项 15 的备选）。两者保留，IC156 断言 6 以恰两个豁免名钉住。
7. `testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys` 现钉 39 条，函数名过时（CLAUDE.md 待开重构卡已列）。
8. IC156 断言 6 的 `S0DeckMetrics.` = 153 与豁免集是对当前内容的精确钉值，今后类别页或登记表任何增删都要同步改（复核子代理也指出）。
9. 测试侧剥离器（各文件自带的 `strippedSource`）不处理 `/* */` 块注释与 `"""` 多行字符串；当前被扫文件里两者都没有（复核子代理指出，本机 `gates.py` 结构检查同结论）。
10. **写卡与执行共同的盲点（供决策会话参考）**：本卡第一次出现「多元素借用集」，而既有断言的写法是在一元素时写下的。惯例 43（先移植跑夹具）能复算计数与集合内容，复算不了 Swift 的重载与类型推断。今后「集合 vs 字面量」类断言，建议卡面直接给出 `Set([...])` 写法。

## 十四、SHA 核验

### 合并后复核

推送合并之后重读 `git ls-remote origin 'refs/heads/*'`，共 86 条：
- `main` = `096fb08695972acafed660a9fc1423e3006d4245`，`feature/ic-165-deck-formal` = `dc7e49459f15fb6227c3f34903357ae490aaa7ed`。
- 其余 84 条与合并前那次读数逐行 `diff` 为空，含 G927 表里十二条被保护分支与 IC-164 分支。
- 本地 `HEAD` = `096fb08`，工作树除本报告目录 `Reports/IC-165/` 外无改动。

### 40 位 SHA 核验

对两份报告全文用正则 `(?<![0-9A-Za-z])[0-9a-f]{40}(?![0-9A-Za-z])` 提取全部 40 位十六进制串，去重得 **50 个**。对每个先 `git cat-file -t <sha>` 取类型，再跑 `git cat-file -e <sha>^{<类型>}`。**50 个退出码全部 0，失败 0**（commit 20、tree 15、blob 15）：

- **commit（20）**：`096fb08695972acafed660a9fc1423e3006d4245`、`180b052edf24f168712c6e58754c60b88b342175`、`1f8ff9248e312cd4a04faec559ea9f34540b1379`、`243e3ad666bea8471ddb6c032e188dc34cc9c374`、`402cb6e52a11dc89ce2a8351b47314a5fe9185b8`、`486bcb769b59eb1146c5a231c7998847206777cc`、`4b6929c89c0578375106eedef858a910a9191788`、`562f8b7afa14508e3efebbd57e980e275946ab95`、`5cb67332437a446d98733ddc942e2905392d2891`、`5e968143822983d6f5ad00f77f44d8a04c3cd474`、`6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d`、`9db02b93eccbb87d126602901807e70823535111`、`a7cc1ec727a3a493f5263e688a316cbf4c743562`、`b368a6caee846e664391b0620350395bfe6fbc7f`、`b6b8464f7de1998173140cdbc816c37dcaefc909`、`c7466fb371d9e23d1ffc39b81a21b125230a7a85`、`cc85fa4a7cfa272092a3acfade432d13de7e4e0b`、`d373afc7125104c01acfc296829229090e6871ce`、`dc7e49459f15fb6227c3f34903357ae490aaa7ed`、`fbee8b1e24815f248fd67bcc02d59b64eea72dad`
- **tree（15）**：`175b165b22c7a7e7c70dd6fdcb28e9afd58fca55`、`265ead14712637be217e9f9e54ba726e5a316d70`、`2cd65e75506d7b0ca383d072c72a75352dd558d5`、`514886dc0afc4083237c976c0f7be6ce597c50a8`、`5bb26f016d35fb1327fccef002da4e7c1921eec1`、`62cdbafc8b45291bf80fe22a2550934c91a39691`、`74088388c62a10eb277921ecf74e766a2d407e80`、`7b8d2b24940be51716d9c605a8b284eb9a191270`、`86fe9d4b2955830c9e4c1407cb69b7aaba5a7b5a`、`922e91638d2b4564b8e4061e0270f44b28f114e7`、`a8ae7e545b8b8809f300c5ba47081c16c84c51e0`、`d6bce474b5e07285a379ad4dcebe59c1bde69d81`、`d738ec8e91342012ab2e9b415e76949b8bc33f05`、`e012ac1468677568df82e8881938a16ea7cf28e9`、`f43aa47cafbecac163209e90c38a7adfd0b4fafe`
- **blob（15）**：`42213bd2eb6774ddb826f2ff2150850150eebe6c`、`541070cf03a039fddf14560b119b5da5a7c93b92`、`579f40df2d2f973aadc5216b3880539b21ac31c4`、`6a5c321e06e5b1b33908b19623e11294f05174a1`、`9a80395451f031f86e30873917f003c63c10c6c3`、`adaa2e10700afc84ec6c6d0c986c17908769f804`、`bea428d8974ad233476f6cb8ceedb315449ec5db`、`c1424f9166525d4b5d72f60f745df38a5ee340c3`、`c8047dc5ce08ac727a8e958f1ee734f14404fefe`、`ccf23fcd3eeef3996b18cdc833af058d7af1f1e8`、`e126f0e1fc712f9acc4c01b2d91e0dcf846c9aea`、`e9a605b039aa558ef18d548a1a13ff99cee13533`、`f1d49b69bf8d019578a92e5204c4714c08cf6dfa`、`f506bf53dbfc8190ec052bde9a35a4a99f574657`、`f5616d84aef4fa537388cf02a372949259e6b6a3`

补充说明：
- 每个 SHA 都取自本会话里实读命令的输出：`git rev-parse`、`git ls-remote`、`git log`、`git reflog`、CI 的 `run.json`。
- 64 位的 IPA SHA-256 与 artifact digest 不在上述 40 位核验范围内，逐字取自 CI 注解与 artifacts API 原文。
- 本 docs 提交自身的 SHA 在提交前无法写进报告，按惯例 44 不回填。
