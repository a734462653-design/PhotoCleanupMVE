# IC-150 自验报告

## 一、结论（先行）

- **两个子项都已交付。** CI **#300 attempt 1 一次绿**：11 个步骤全 success、真实退出码 **0**、**798 项 0 失败**（791 + 本卡新增 7）、目的地 `OS:26.2, name:iPhone 16`。
- **子项 A 的根因已定**：卡内三种可能里，**两种被 Lynn 自己的两个数据点排除**，剩下的一种与读码给出的生命周期缺陷逐条吻合。改法不依赖机制细节的精确性——把原始字节复制进自己的容器，从根上不再依赖 PhotoKit 容器的沙盒扩展。
- **子项 B 两个症状确是两个根因**，按卡要求分开查：症状 1 是**类目**（静音路径从不设类目，会话停在不混音的 `.soloAmbient`），症状 2 是**停用时播放器仍在跑音频 I/O**（`setActive(false)` 抛 busy，被 `try?` 吞掉）。
- **既有六条绿测没抓到真机那条的原因已写明**（第五节 5.4），按陷阱 1 标注「夹具驱动、真机未覆盖」，**没有为了让它变绿而放宽任何断言**。
- **人工判定项 H72 六条原样保留给 Lynn**，执行端不代为下结论。

---

## 二、输入、继承提交、目标分支、范围边界

| 项 | 值 |
|---|---|
| 任务卡 | `<top>/Tasks/IC-20260915-150-s2-share-and-audio.md` |
| 基线 `main` | `7b5c9233f01ca4992449ca86295c9e9b70fa6b21` |
| 开工核对 | `git merge-base --is-ancestor 07b2799 main` 退出码 **0** ✔（IC-149 已由决策会话合并） |
| 开工 `git status --porcelain` | 空 ✔（纪律 8） |
| 分支 | `feature/ic-150-s2-share-and-audio` |
| 分支 tip（代码） | `64839118e4be1543b14c8972123c2037cc305678` |
| 现状基数 | 791 项 → 本卡 **798** 项（新增 7） |

范围边界：7 个文件；S0／S1／S3／S4／S5／`Core/`／`Services/`／`.github/`／`Scripts/` 各 **0** 命中。详见 `change-list.md` 第二节。

---

## 三、子项 A：为什么照片那条不行（卡内硬要求「先测再改」）

### 3.1 三种可能的逐一排除

任务卡列出三种可能，并明确「决策会话没有替你判这一条」。**其中两种用 Lynn 原话里的两个数据点即可排除**：

| 可能 | 判定 | 依据 |
|---|---|---|
| (b) 接收方不接受 **HEIC** 这个 UTI | **排除** | 原话里**截图也分享不出去**。iOS 截图是 **PNG**，不是 HEIC。若病根在 HEIC 的 UTI，PNG 截图应当能分享 |
| (c) `UIActivityViewController` 拿裸 URL 时不做类型协商 | **排除** | 原话里**视频可以**。视频那条走的是同一个 `S2ShareSheet`、同样 `UIActivityViewController(activityItems: [url])`、同样是一个**裸文件 URL**（`AVURLAsset.url`）。协商这一环对两侧是同一套代码，它若坏，视频也该坏 |
| (a) 那个路径**读不到** | **剩下这一种** | 见下 |

这两条排除是 ①：前提（截图是 PNG、视频与照片共用同一个面板与同一种载荷）都可核验，结论只是逻辑消去。

### 3.2 与 (a) 吻合的代码事实（①，读 `7b5c923`）

```swift
private func imageURL(for asset: PHAsset) async -> URL? {
    await withCheckedContinuation { continuation in
        ...
        _ = asset.requestContentEditingInput(with: options) { input, _ in
            ...
            continuation.resume(returning: input?.fullSizeImageURL)
        }
    }
}
```

- `input` 是**回调的入参**，回调一返回即释放；**只有 URL 这个值逃了出去**。
- `fullSizeImageURL` 指向 PhotoKit 容器（`/var/mobile/Media/…`）里的原文件，不在本 App 容器内。
- 照片、实况、截图**三者共用这个函数**（`mediaType != .video` 全走这里）；视频走 `videoURL(for:)`，**不共用**。

这与「三废一可用」的现象逐条吻合：**分界线正是这两个函数，不是资产类型、不是文件格式。**

### 3.3 证据分级与未尽之处（如实标注）

- 「(b)(c) 被排除」——①（前提可核验、结论为逻辑消去）
- 「三者共用 `imageURL`、视频不共用」——①（读码）
- 「`PHContentEditingInput` 释放后该路径不再可读」——**③推测**。本机无 Xcode、无真机，CI 的模拟器也拿不到相册授权，**这一层机制我没能实测**。
- **本卡的改法不依赖这一层是否精确**：无论是「面板读不到」「接收方读不到」还是「沙盒扩展已失效」，把原始字节复制进本 App 自己的临时目录都同样解决。**怎么验证**：H72 第 1 项，四类资产各分享一次。

### 3.4 改法

`PHAssetResourceManager.writeData(for:toFile:options:)` 把原始资源写进 `FileManager.default.temporaryDirectory/S2Share/`，返回该 URL。

- **不转码**——规格第 4 条要的是原始资产，卡内也明令「不要直接套『转成 JPEG 就行』」。
- 资源选取：编辑过取 `.fullSizePhoto`，否则取 `.photo`；实况只取静态图，不取 `.pairedVideo`。
- 视频那条（本来能用）**一字未动**。
- 禁网络不变：两处请求选项都 `isNetworkAccessAllowed = false`，iCloud 未下载的取不到即回 nil、不呈现空面板。
- 分享目录每次先整个清空：`writeData` 要求目标文件不存在，且 `S2SharePayload` 一次只承载一个 URL。

### 3.5 `Services/` 那份同源实现（登记，本卡不动）

`AssetSizeProbeService` 的 URL 途径原与本处同源。**IC-150 A 之后照片一侧不再同源**：那条只量字节数，在本进程内当场读完即弃，用 `fullSizeImageURL` 没问题；分享要把 URL 交给面板之后才被读，必须落在自己的容器里。

**结论：`Services/` 那份不需要跟改**（它的用法不受该生命周期约束）。已在源码注释里改写登记。视频一侧两处仍同源。`Services/` 本卡一行未动（在 G857 的零改动清单里，实证 0 命中）。

---

## 四、子项 A 的断言

| 断言 | 测试函数 | 结果 |
|---|---|---|
| 1（四类资产各一条路径） | `testIC150AAssertion01EveryMediaKindResolvesToAShareableItem` | **passed** 0.607s |
| 1b（旧容器路径口径已废） | `testIC150AAssertion01bResolverNoLongerHandsOutTheLibraryContainerURL` | **passed** 0.019s |
| 2（只分享当前这一张） | **沿用既有** `testIC146A_ShareDiscardsFailedAndStaleResolutions` | **passed** 0.332s |
| 3（状态零影响） | **沿用既有** `testIC146A_ShareLeavesEveryStateUntouched` | **passed** 0.001s |
| 4（禁网络不变） | `testIC150AAssertion04NetworkAccessStaysDisabledOnEveryPath` | **passed** 0.015s |

断言 2、3 **口径未放宽，一字未改**。

断言 4 的正对照：除了「`= false` 恰两处」「`= true` 为 0」，还断言 `isNetworkAccessAllowed` 本身命中非零——否则前两条在 needle 写错时永远成立（空转）。

---

## 五、子项 B：两个症状、两个根因

### 5.1 症状 1 · 静音播放也打断别人（根因：类目）

卡内 ③ 假设基本成立，且可由读码坐实：

- B2 实证：全仓只有一处 `setCategory`，且**只在「用户点了有声」那条分支里被调**（`updateAudioSession` 的 `unmuted` 分支）。静音播放**一次都不设类目**。
- 未设过类目 ⟹ 会话停在 **App 默认类目 `.soloAmbient`**，它**不混音**。
- `AVPlayer.play()` 会**隐式激活**会话；B5 的 `isMuted` 是**播放器级**的，只把音量拧到 0，改不了类目也拦不住隐式激活。

**改法**：类目跟着「是否出声」走——静音 `.ambient`（可混音、跟随侧面拨片），出声 `.playback`（H65 第 8 项「拨片静音也出声」不变）。

> **卡内断言 5 的写法抓不到这个缺陷，已按实际补强。** 原文要求「静音播放走完整条序列后，会话桩**零次**收到激活」。但改前静音路径本就不调 `setActive(true)`（`if unmuted` 直接跳过），**这条断言在改前就是绿的**，而真机是坏的。故断言 5 除了保留「零次激活」，**另加一条钉住类目**：静音态 `calls == ["setCategory(.ambient)"]`。这是「断言在正确实现前会不会必然失效」的那一问（惯例 37）。

### 5.2 症状 2 · 开声后回 Home，音乐不恢复（根因：停用时仍有音频 I/O）

卡内给了三个候选方向，逐一核过：

| 候选 | 判定 | 依据 |
|---|---|---|
| `updateAudioSession(unmuted: false)` 真机上**没被调到**（scenePhase 时序） | **排除** | 事件链完整：`applicationDidResignActive()` → `send(.applicationDidResignActive)` → reducer 把 `isUnmutedByUser` 清成 false → `send` 末尾 `if !unmuted { updateAudioSession(false) }`。幂等守卫此时 `audioSessionIsActive(true) != false` 成立，**不会短路** |
| `AVPlayer` 在我们停用之后又把会话隐式激活回去 | **不是主因** | 若如此，`setActive(false)` 本身应当成功、别的 App 会**先恢复再被打断**；Lynn 的现象是「不会自动播放」，即从未恢复 |
| **B3 的 `try?` 把抛出的错误静默吞掉；停用前没先暂停播放器** | **是这一条** | 见下 |

**读码坐实（①）**：reducer 的 `.applicationDidResignActive` 分支只返回 `[.setMuted(assetID:, muted: true)]`——**只静音，不暂停**。`isMuted` 只把音量拧到 0，**音频管线照跑**。于是 `setActive(false, options: .notifyOthersOnDeactivation)` 是在一个仍有运行 I/O 的会话上调用的，真机会抛 `AVAudioSession.ErrorCode.isBusy`（`!act`），而 B3 用 `try?` 把它整个吞掉 ⟹ `.notifyOthersOnDeactivation` **从未真正送出** ⟹ 别的 App 收不到「可以恢复」。

**改法两层**：

1. reducer 在失活时若当前页仍 `.playing`，**一并发 `.pause` 并把状态改 `.paused`**。`send()` 的既有顺序是 `apply(effects)` 在 `updateAudioSession(false)` **之前**，所以暂停天然排在停用之前，不必动那个顺序。
2. 会话协议改为**回报成败**；`updateAudioSession` 只有真的成功了才翻 `audioSessionIsActive` 的记账。旧实装是**先翻记账再调用**，调用失败也当成功记账，此后幂等守卫永远挡着不再重试——这是第二层保险。

### 5.3 行为副作用（如实报告，留给 H72 判）

失活时若在播，现在**会暂停**（旧行为是只静音、继续静默播放）。`applicationDidResignActive` 也会在通知中心下拉、控制中心等非后台场景触发，那些时候视频也会停。**停掉音频 I/O 是让别的 App 恢复的必要条件**，没有别的办法；但这一条是否是 Lynn 想要的观感，请在 H72 一并看。

### 5.4 为什么既有六条绿测没抓到真机那条（卡内硬要求）

**记录器是个不会抛的桩。** `IC146AudioSessionRecorder.setActive(_:)` 收到调用就往 `calls` 里记一笔然后返回——它**没有失败这条路**。于是：

- 真机上 `setActive(false)` 抛 `!act` 什么都没做 → 夹具看到的是「调过了，恰一次」→ **绿**。
- 真机上 `AVPlayer.play()` 隐式激活了一个 `.soloAmbient` 会话 → 夹具根本看不见隐式激活，也看不见当时生效的是哪个类目 → 「零次激活」**绿**。

两条都是典型的**陷阱 1（夹具全绿、真机不过）**。本卡的处理：

- **不放宽任何断言**。六条里改口径的只有两条（`autoplay.calls == []`、`idle.calls == []`），而且是**收紧**——从「一次都别碰会话」改成「必须把类目置成 `.ambient`」。旧口径恰恰是在断言那个缺陷。
- 新记录器仍**一律回 true**，并在注释里写明「真机上的抛错夹具这一侧模拟不出来」。可失败的那一侧由 `IC150AudioSessionRecorder.succeeds = false` 单独钉「失败不改记账、留待重试」——那是**协调器对返回值的处理**，可测；**系统会不会抛**，不可测，归 H72。

### 5.5 子项 B 的断言

| 断言 | 测试函数 | 结果 |
|---|---|---|
| 5（静音不激活 + 类目为 `.ambient`） | `testIC150BAssertion05MutedPlaybackNeverActivatesTheSession` | **passed** 0.005s |
| 6（停用可观察、不被守卫短路、失活时先暂停） | `testIC150BAssertion06ResignActiveDeactivatesWithoutBeingShortCircuited` | **passed** 0.002s |
| 7（`try?` 不再静默，错误有去向） | `testIC150BAssertion07SessionErrorsHaveAnObservableDestination` | **passed** 0.103s |
| 8（回归：再回 S2 仍静音） | `testIC150BAssertion08ReturningToS2StaysMuted` | **passed** 0.001s |
| 8（回归：`AVAudioSession` 仍只在生产实现里） | **沿用既有** `testIC146D_AVAudioSessionStaysInsideTheProductionImplementation` | **passed** 0.017s |

断言 7 的**允许清单与理由**：源码扫描断言「适配器里 `try?` 为 0」。正对照用的是 `S2View.swift` 里 `try? FileManager.default.removeItem(at: directory)` ——**这一处允许保留裸 `try?`**：删的是一个本就可能不存在的临时目录，失败无害；真正的错误由随后的建目录与 `writeData` 回报。它同时证明 `try?` 这个 needle 确实能命中，否则「适配器里为 0」有可能是 needle 写错导致的空转。

---

## 六、闸门逐条

### G857（范围）

| 项 | 结果 |
|---|---|
| diff 限于白名单 | ✔ 7 个文件 |
| S0／S1／S3／S4／S5／`Core/`／`Services/`／`.github/`／`Scripts/` 零改动 | ✔ 各 **0** 命中（逐前缀 `grep -c` 输出见 `change-list.md` 第二节） |
| `S2AmbientBackdrop.swift` 两侧 SHA-256 相同 | ✔ **`ee5ed62d36d1fe69264a8aeae8d66ba345a3df71417d1e3b16f1709ae7813006`**（氛围底归下一张卡，本卡一行未碰） |

### G858

| 项 | 结果 |
|---|---|
| `S2Calibration.swift` 不在 diff | ✔ `grep -c` = 0；两侧 SHA-256 `b06168a00987d70d17e9a41b2525a5fce18a0f2cb081c1d70576e7382087410f` |
| `schemaVersion` = 7 | ✔ `:118` `static let schemaVersion = 7` |
| 冻结三链 + 三条探针远端 tip 未变 | ✔ 见 `change-list.md` 第六节，与 CLAUDE.md 逐条相符 |

### G859（既有六条测试）

| 测试函数 | 结果 | 口径 |
|---|---|---|
| `testIC146A_ShareLeavesEveryStateUntouched` | **passed** | 未动 |
| `testIC146A_ShareDiscardsFailedAndStaleResolutions` | **passed** | 未动 |
| `testIC146D_ResignActiveDeactivatesTheSessionExactlyOnce` | **passed** | **改**（3 处，见 `change-list.md` 第四节） |
| `testIC146D_ReturningToActiveDoesNotReactivateUntilUserTapsUnmute` | **passed** | 未动 |
| `testIC146D_ResignActiveClearsUnmuteIntentInTheReducer` | **passed** | 未动 |
| `testIC146D_AVAudioSessionStaysInsideTheProductionImplementation` | **passed** | 未动 |

另有两条 IC-143 的会话测试受同一口径影响，一并列入 `change-list.md` 第四节：
`testIC143D_UnmutingActivatesTheSessionAndEveryMutePathDeactivates`（**passed**，改 5 处）、
`testIC143D_TheAudioSessionIsTouchedInExactlyOnePlace`（**passed**，未动）。

旧→新逐条与「为什么旧口径测不出真机那条」见 `change-list.md` 第四节与本报告 5.4。

### G860（合并前置）

| 项 | 结果 |
|---|---|
| G857／G858／G859 | ✔ |
| 绿 | ✔ #300 attempt 1，11 步全 success，真实退出码 **0** |
| 摘要 notice | `Executed 798 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 798 tests / 0 failures` |
| 目的地实证行 | `{ platform:iOS Simulator, arch:arm64, id:2911FD29-A09E-4A81-BEA7-99A616FB7FC8, OS:26.2, name:iPhone 16 }` |
| IPA | **1572752 字节**，SHA-256 `6d81cc8d6dc20e7129733689b772d07eb4173a52df701419db35e8944a7a0441` |
| 断言 1～8 逐条给函数名并在日志核 `passed` | ✔ 第四、五节，15 个函数逐条 `passed` |
| 项数对账 | ✔ 791 + **7** = **798**；日志唯一用例行计数 **798**（started 798 / passed 798 / failed 0 / 重启标记 0），与 notice 一致 |
| 工作树净 | ✔ |
| `main` 未被他人推进 | ✔ `git ls-remote origin refs/heads/main` = `7b5c9233f01ca4992449ca86295c9e9b70fa6b21` |

**G860 满足** ⟹ 按卡内授权 `--no-ff` 合并推送。结果见第十节。

### G861（合并后 `main` 运行）

见第十节。

---

## 七、CI

| 项 | 值 |
|---|---|
| run 编号 / id / attempt | **#300** / `34992955407` / attempt 1（**一次绿**，未复跑） |
| 被测提交 | `64839118e4be1543b14c8972123c2037cc305678` |
| 结论 | success，真实退出码 **0** |
| 步骤 | 11 步全 success（含 IC-149 落地的结构自验与项数统计自测两步） |
| 项数 | **798**，0 失败，0 重启 |
| 目的地 | `OS:26.2, name:iPhone 16`，工具链 `/Applications/Xcode_26.3.app` |
| IPA | 1572752 字节，SHA-256 `6d81cc8d6dc20e7129733689b772d07eb4173a52df701419db35e8944a7a0441` |

CI 预算 3 次，**实际用 1 次**。

---

## 八、本地门禁结果与真实退出码

| 门禁 | 退出码 |
|---|---|
| `Scripts/selfcheck.ps1`（含下面两条与硬编码扫描） | **0** |
| `Scripts/check-swift-string-structure.ps1 -SelfTest`（IC-149 门禁一） | **0**（75 个 `.swift` 全过；自对照两病样各判红、健康样本零命中） |
| `Scripts/check-scan-needle-variant.ps1 -SelfTest`（IC-149 门禁二） | **0**（**35** 个测试源文件全过——含本卡两个新文件） |
| `git diff --check`（两次暂存） | 无输出 |

### 本机预验证（卡内硬要求，IC-147／IC-148／IC-149 三次实证这一步能当场抓到必红缺陷）

推 CI 前把两类断言移植成 Python 跑过：

| 预验证 | 条数 | 结果 |
|---|---|---|
| 源码扫描断言（断言 4、1b、7 + 既有 `AVAudioSession` 归属四条） | 16 | **全过** |
| 会话调用序列模拟（IC-143 六处、IC-146 五处、本卡断言 5／6／7 共 …） | 29 | **全过** |

会话模拟直接产出了 IC-143／IC-146 被改口径的**新期望值**，不是事后凑的——这是本卡 CI 一次绿的直接原因。

---

## 九、人工判定项（H72，留给 Lynn 真机，执行端不代为下结论）

1. **分享四种资产各一次**：普通照片、实况、截图、视频——都能分享出去，不再出现「暂时不支持此类型内容的分享」。
2. 分享的仍是**当前这一张**；关掉面板后 chrome 显隐、缩放、标记状态、视频播放状态都和点之前一样。
3. **静音播放不打断别人**：别的 App 放音乐 → 进 S2 翻到视频（默认静音）→ **音乐应继续放**。
4. **开声打断、回 Home 恢复**：点「有声」音乐停 → 按 Home 回桌面 → **音乐应恢复**。
5. **回 S2 仍是静音**：再进 S2，视频是静音的，要再点「有声」才出声（H69 已判过的行为，确认没回归）。
6. **H69 其余四项不回归**：底排三件、氛围底、已标记撤销、H65／H66 回归各快过一遍。

**另请在第 3／4 项时一并看 5.3 的副作用**：失活时若视频在播，现在会**暂停**（旧行为是继续静默播放）。这是让别的 App 恢复的必要条件，但观感是否可接受请一并判。

---

## 十、合并与 G861

**G860 满足，按卡内授权执行 `--no-ff` 合并并推送。合并未被权限分类器拒绝，一次通过。**

| 项 | 值 |
|---|---|
| 合并提交 | **`53bc9ed5a877476e7e09178f05c06f34accb6315`** |
| 父提交 | `7b5c9233f01ca4992449ca86295c9e9b70fa6b21`（合并前 `main`）、`466f559be84206edf673f4156f1cc5e49fe52d2b`（分支 tip，含报告） |
| 合并后 `main` 树 vs 分支 tip 树 | **逐字节一致**（`git diff --stat 466f559 HEAD` 无输出） |

### G861：合并后 `main` 自动运行

| 项 | 值 |
|---|---|
| run 编号 / id / attempt | **#301** / `34994414936` / attempt 1 |
| 被测提交 | `53bc9ed5a877476e7e09178f05c06f34accb6315` |
| 结论 | **success**，11 个步骤全 success |
| 摘要 notice | `Executed 798 tests, 0 failing test case(s), across 1 launch(es); xcodebuild last-chunk subtotal: 798 tests / 0 failures` |
| IPA | **1572752 字节**，SHA-256 `875160a4ee0142e165ca6464520367c828054ae36f3209758bba72259efeceaf` |

IPA 字节数与分支运行 #300 **相同**而 SHA-256 **不同**，与既有结论一致：IPA 归档不可复现，同一性以树 diff 为准、不用哈希（上表的树比对即为此）。

本节属合并后才产生的信息，按纪律 7 以**同卡 docs 提交**回填；因合并已落 `main`，该提交直接落 `main`（`Reports/**` 命中 `paths-ignore`，不触发 CI，这是预期行为）。

---

## 十一、发现但未处理的问题（按纪律只报告不修）

1. **「用户再点一次静音」这条路径上，停用会话同样可能因 busy 失败。** 本卡只在**失活**路径上补了暂停（那是卡内指定的目标）。用户主动点静音时播放器仍在播，`setActive(false)` 在真机上可能照样抛；本卡的第二层保险（失败不改记账、下次重试）能缓解但不保证当场恢复。**在那条路径上「暂停」显然是错的 UX**，怎么处理需要决策会话定。H72 第 3／4 项若顺带发现「点静音后音乐也不恢复」，即为此项。
2. **`AVPlayer` 在我们停用之后是否会再隐式激活回去**，本卡未能实测（无真机）。若 H72 第 4 项仍不恢复，这是下一个要查的方向。
3. **子项 A 的机制那一层仍是③**（见 3.3）。H72 第 1 项是唯一的确认途径。
4. **`S2SharePayload` 里的 URL 现在指向自己的临时目录**，系统清理临时目录的时机不受我们控制。面板呈现期间被清掉的概率极低（同一次交互内），但这是一个新引入的、理论上的时间窗，此前没有。
5. **失活时暂停视频是可见的行为变化**（5.3），已列入 H72 请 Lynn 一并判。
6. **`AssetSizeProbeService` 的结论是「不需要跟改」**（3.5），但那是基于「它只在本进程内当场读完即弃」这一读码结论；`Services/` 本卡未动、也未跑其测试，如与事实不符请回报。

---

## 十二、SHA 核验

本报告与 `change-list.md` 中出现的全部 40 位 SHA，逐个跑 `git cat-file -e <sha>^{commit}`：

| SHA | 含义 | `cat-file -e` |
|---|---|---|
| `7b5c9233f01ca4992449ca86295c9e9b70fa6b21` | 基线 `main`（IC-149 合并提交） | **OK** |
| `07b27991c42dde24db0cc20dd60f6f6f558d30af` | 开工核对用（IC-149 子项 C） | **OK** |
| `9e1eee8a11b6a21c106a45d6c5adaa26005d8816` | 本卡提交 1（子项 A） | **OK** |
| `64839118e4be1543b14c8972123c2037cc305678` | 本卡提交 2（子项 B），#300 被测提交 | **OK** |
| `466f559be84206edf673f4156f1cc5e49fe52d2b` | 本卡报告提交，分支 tip | **OK** |
| `53bc9ed5a877476e7e09178f05c06f34accb6315` | 合并提交，#301 被测提交 | **OK** |
| `b368a6caee846e664391b0620350395bfe6fbc7f` | 冻结链 `feature/ic-089-nx-edge-bounce` | **OK** |
| `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | 冻结链 `feature/ic-091-nx-midgesture-handoff` | **OK** |
| `a7cc1ec727a3a493f5263e688a316cbf4c743562` | 冻结链 `feature/ic-092-nx-window-follow` | **OK** |
| `9db02b93eccbb87d126602901807e70823535111` | `probe/ic-067-screenshot-subtype` | **OK** |
| `486bcb769b59eb1146c5a231c7998847206777cc` | `probe/ic-137-media-playback` | **OK** |
| `d373afc7125104c01acfc296829229090e6871ce` | `probe/ic-145-scan-service` | **OK** |

十二个全部存在，无一例外。陷阱 15：本报告所有 40 位 SHA 均来自 `git rev-parse` / `git log` / `git ls-remote` 的实读输出，无一例由短前缀补全。

**非提交类哈希**（文件内容、IPA）均为本机 `sha256sum` 或 CI `shasum -a 256` 的实测输出，不参与 `cat-file` 核验。
