# IC-150 变更清单

- 分支：`feature/ic-150-s2-share-and-audio`
- 基线：`main` = `7b5c9233f01ca4992449ca86295c9e9b70fa6b21`（IC-149 合并提交）
- 分支 tip（代码）：`64839118e4be1543b14c8972123c2037cc305678`
- 提交数：2 个代码提交 + 1 个报告提交（本文件所在提交）

---

## 一、提交清单

| # | SHA | 类型 | 标题 | 可单独 cherry-pick |
|---|---|---|---|---|
| 1 | `9e1eee8a11b6a21c106a45d6c5adaa26005d8816` | fix | 子项 A——分享把原始字节写进自己的容器，四类资产都能分享 | 是 |
| 2 | `64839118e4be1543b14c8972123c2037cc305678` | fix | 子项 B——静音走 `.ambient`、退后台先暂停再停用、会话错误不再静默 | 是 |

**两个提交无重叠文件**（`project.pbxproj` 各自只登记自己那个测试文件，行不相交），故 A／B 可各自单独 cherry-pick。为此新测试拆成两个文件而不是一个——一个文件会让「只 cherry-pick B」时缺掉该文件。

---

## 二、文件变更全量（`git diff --name-only main...HEAD`）

```
PhotoCleanupMVE.xcodeproj/project.pbxproj
PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift
PhotoCleanupMVE/Features/S2/S2View.swift
PhotoCleanupMVETests/IC143VideoPolishTests.swift
PhotoCleanupMVETests/IC146ChromeRoundTwoTests.swift
PhotoCleanupMVETests/IC150AudioSessionTests.swift
PhotoCleanupMVETests/IC150ShareTests.swift
```

零改动目录实证（`git diff --name-only main...HEAD | grep -c` 各前缀）：

| 前缀 | 命中 |
|---|---|
| `PhotoCleanupMVE/Features/S0/` | **0** |
| `PhotoCleanupMVE/Features/S1/` | **0** |
| `PhotoCleanupMVE/Features/S3/` | **0** |
| `PhotoCleanupMVE/Features/S4/` | **0** |
| `PhotoCleanupMVE/Features/S5/` | **0** |
| `PhotoCleanupMVE/Core/` | **0** |
| `PhotoCleanupMVE/Services/` | **0** |
| `.github/` | **0** |
| `Scripts/` | **0** |

---

## 三、逐文件说明

### 1. `PhotoCleanupMVE/Features/S2/S2View.swift`（子项 A）

| 处 | 动作 |
|---|---|
| `S2PhotoKitShareItemResolver.imageURL(for:)` | **重写**。原先返回 `PHContentEditingInput.fullSizeImageURL`（PhotoKit 容器路径），改为用 `PHAssetResourceManager.writeData` 把原始字节写进 `temporaryDirectory/S2Share/` 再返回该 URL |
| `shareableImageResource(for:)` | **新增**静态助手。编辑过取 `.fullSizePhoto`，否则取 `.photo`；实况只取静态图，不取 `.pairedVideo` |
| `prepareShareDestination(filename:)` | **新增**静态助手。每次先清空 `S2Share` 目录（`writeData` 要求目标不存在，且一次只该留当前这一张） |
| `videoURL(for:)` | **一字未动**（A6 本来就能用） |
| 类注释 | 更新：照片一侧与 `AssetSizeProbeService` 不再同源，并登记 `Services/` 是否需跟改 |
| `S2SharePayload` / `S2SharePreparation` / `S2ShareSheet` / `.sheet(item:)` 接线 | **一字未动** |

### 2. `PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift`（子项 B）

| 处 | 动作 |
|---|---|
| `S2AudioSessionCategory` | **新增**枚举（`ambient` / `playback`） |
| `S2AudioSessionControlling` | **改签名**：`setPlaybackCategory()` → `setCategory(_:) -> Bool`；`setActive(_:)` → `setActive(_:notifyOthersOnDeactivation:) -> Bool` |
| `S2SystemAudioSession` | **重写**：裸 `try?` 改 do/catch，错误落 `lastFailure` 并经返回值回报；`.ambient` 分支新增 |
| `updateAudioSession(unmuted:)` | 类目改成两侧都设（静音 `.ambient`）；激活／停用**失败不改记账**，留待下次重试 |
| `applyAudioCategory(_:)` | **新增**，类目的幂等写入口（仍是单一写入点，陷阱 19 不破） |
| `appliedAudioCategory` / `audioSessionFailureCount` | **新增**两个字段；后者是断言 7 要求的「可观察去向」 |
| reducer `.applicationDidResignActive` | 若当前页仍 `.playing`，**追加 `.pause` 并把状态改 `.paused`**——停用会话前先停掉音频 I/O |

### 3. `PhotoCleanupMVETests/IC150ShareTests.swift`（新）

断言 1、1b、4。含取项桩 `IC150ShareResolverStub`。

### 4. `PhotoCleanupMVETests/IC150AudioSessionTests.swift`（新）

断言 5、6、7、8。含会话记录器 `IC150AudioSessionRecorder`（带 `succeeds` 开关，用来钉「失败不改记账」）。

### 5～6. 既有测试的口径改动

见第四节。

### 7. `PhotoCleanupMVE.xcodeproj/project.pbxproj`

两个新测试文件各 4 条登记（`PBXBuildFile` / `PBXFileReference` / group children / Sources build phase）。

**对象 id 撞号扫描**（陷阱：撞号不报错，后登记的文件会静默掉出编译列表）：加登记前重扫当前最大号，`1xxx` 段最大 `100000000000000000000050`、`2xxx` 段最大 `20000000000000000000004D`，故取

| 文件 | fileRef | buildFile |
|---|---|---|
| `IC150ShareTests.swift` | `100000000000000000000051` | `20000000000000000000004E` |
| `IC150AudioSessionTests.swift` | `100000000000000000000052` | `20000000000000000000004F` |

加登记前对两个新 id 各跑 `grep -c` 得 **0**（未被占用）。`files = (` 命中行即上面 group children 与 Sources 两处，逐条核过。落地实证：CI #300 的 `Executed 798 tests` = 791 + 7，**新文件确实进了编译列表**（若撞号掉出，项数会停在 791 而 CI 照绿）。

---

## 四、既有测试口径改动（G859 要求的旧→新）

### 4.1 为什么要改

三处断言都在说同一件事：**「静音态一次都别碰音频会话」**。而那正是 H69 第 5 项症状 1 的成因——不碰会话，类目就停在 App 默认的 `.soloAmbient`（不混音），`AVPlayer.play()` 一隐式激活就打断别人的音乐。新口径是**「静音态把类目置成可混音的 `.ambient`，但不激活」**。

**为什么旧口径测不出真机那条**：记录器只看得见「我们主动调了哪些会话方法」，看不见 `AVPlayer.play()` 的**隐式**激活，也看不见当时生效的是哪个类目。断言「零调用」在改前改后都能绿，真机却是坏的——典型的陷阱 1。

### 4.2 `IC143VideoPolishTests.swift`

| 位置 | 旧 | 新 |
|---|---|---|
| 记录器 `AudioSessionRecorder` | `setPlaybackCategory()` / `setActive(_:)`，无返回值 | `setCategory(_:) -> Bool` / `setActive(_:notifyOthersOnDeactivation:) -> Bool`，一律回 `true` |
| `autoplay.calls` | `[]` | `["setCategory(.ambient)"]` |
| `retap.calls`（点有声后） | `["setCategory(.playback)", "setActive(true)"]` | 前置一条 `"setCategory(.ambient)"`，共 3 条 |
| `retap.calls.count` | `3` | `5` |
| `pageChange.calls` | 3 条 | 5 条（两处 `.ambient` 各一） |
| `repeated` 末尾增量 | `afterFirstUnmute + 1` | `afterFirstUnmute + 2` |

`unload.calls.last`、`leaving.calls.last`、「出声期间其他事件不重复激活」三条**未动**，仍为原值。

### 4.3 `IC146ChromeRoundTwoTests.swift`

| 位置 | 旧 | 新 |
|---|---|---|
| 记录器 `IC146AudioSessionRecorder` | 同上 | 同上 |
| `active.calls`（点有声后） | 2 条 | 前置 `"setCategory(.ambient)"`，共 3 条 |
| `active.calls`（失活后） | 3 条 | 5 条 |
| `idle.calls` | `[]` | `["setCategory(.ambient)"]` |

`deactivateCount == 1`、幂等重复失活零新增、`testIC146D_ReturningToActiveDoesNotReactivateUntilUserTapsUnmute` 全部断言、`testIC146D_ResignActiveClearsUnmuteIntentInTheReducer` 全部断言、`testIC146D_AVAudioSessionStaysInsideTheProductionImplementation` 全部断言——**一字未动且全绿**。

> 注：`testIC146D_ResignActiveClearsUnmuteIntentInTheReducer` 断言 `effects == [.setMuted(...)]`。该用例里 `"B"` 处于 `.requesting` 而非 `.playing`，故本卡新增的 `.pause` 不触发，断言原样成立。`.playing` 那条由新增的断言 6 覆盖。

---

## 五、占位值登记

**本卡无出厂值变更。** `S2Calibration.swift` 不在 diff（两侧 SHA-256 均为 `b06168a00987d70d17e9a41b2525a5fce18a0f2cb081c1d70576e7382087410f`），`schemaVersion` 仍为 **7**（`:118`），无需递增。

---

## 六、不得触碰项两侧核验

| 文件 | 两侧 SHA-256 | 结论 |
|---|---|---|
| `PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift` | `ee5ed62d36d1fe69264a8aeae8d66ba345a3df71417d1e3b16f1709ae7813006` | **相同**（氛围底归下一张卡，本卡一行未碰） |
| `PhotoCleanupMVE/Features/S2/S2Calibration.swift` | `b06168a00987d70d17e9a41b2525a5fce18a0f2cb081c1d70576e7382087410f` | 相同 |
| `Scripts/test-xcode.sh` | `a1bad7252b9dbebf8f1cbc42c57ef2d0367fbe2f87774c8cb6006a3f007b72d9` | 相同 |

冻结三链与探针分支远端 tip（`git ls-remote origin`，本卡未触碰）：

```
b368a6caee846e664391b0620350395bfe6fbc7f refs/heads/feature/ic-089-nx-edge-bounce
6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d refs/heads/feature/ic-091-nx-midgesture-handoff
a7cc1ec727a3a493f5263e688a316cbf4c743562 refs/heads/feature/ic-092-nx-window-follow
9db02b93eccbb87d126602901807e70823535111 refs/heads/probe/ic-067-screenshot-subtype
486bcb769b59eb1146c5a231c7998847206777cc refs/heads/probe/ic-137-media-playback
d373afc7125104c01acfc296829229090e6871ce refs/heads/probe/ic-145-scan-service
```

与 CLAUDE.md 所记短 SHA 逐条相符。
