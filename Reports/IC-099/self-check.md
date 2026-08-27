# IC-099 自验报告（阶段二：顶部信息区实装，v2）

> v1（`741a2c1`）在 R0 触发闸门 A 并停下报告；H43 真机探针取回数据后技术负责人定案路线，下发 v2。本报告**覆盖 v1**，v1 的 R0 探明结论保留在「v1 闸门 A 的处置」一节。

## 结论（先行）

R1（文本纯函数）、R2（两行信息区实装）、R3（String Catalog）、R4（路线分派 + 缓存 + 异步管线）全部交付。

**CI 结果：CI #173 success**，被测提交 `968998579306fc1a4be861f783a49a3211987114`，XCTest **514 项、0 失败**，9 步全 success，被测命令真实退出码 **0**；IPA **836171 字节**、SHA-256 `454342c72ec64735a139b6aec71e742aa8773d1e0238324049b6bbeba0788044`，本地重下复核逐字节一致。**CI 只用了 1 次**（上限 3）。

计数算式：**508 + 6 − 0 = 514**。本地三项门禁真实退出码全为 **0**。

**未使用任何 KVC 私有键**；未碰产品图片请求策略与节流；**`AssetSizeScanner` 的 S3 语义一字未动**。三道闸门（A 图片请求策略 / 节流 / S3 语义，B 既有门禁，C 标定参数与 `schemaVersion`）**均未触发**。

**H42（v1 原文 + 两项加测）保留给 Lynn 真机判定，本报告不代为下结论。**

## 输入与边界

| 项 | 值 |
|---|---|
| 开工时 `git status --porcelain` | 空 |
| 继承提交 | `3b7d50e46b78184b0f2b18d34b7e6ebb0a95930c`（IC-101 交付，CI #171、508/0） |
| 目标分支 | `feature/ic-099-top-bar-date-index-size`（未重切） |
| 分支 tip（代码部分） | `968998579306fc1a4be861f783a49a3211987114` |
| CI | **#173 success（1/3）** |
| 合并动作 | 无 |

范围边界：新增 `S2TopBarInfoPresentation.swift`（并注册 pbxproj 四处）；改 `Services/AssetSizeScanner.swift`（**只追加** `AssetVolumeService`）、`S2View.swift`（顶部中部信息区 + 两个默认参数 + 接线）、`Localizable.xcstrings`（追加 3 个 key）、`CleanupCoordinator.swift` / `PhotoCleanupMVEApp.swift`（接线）、`S2CalibrationHarnessTests.swift`（6 项断言）。**底部布局、确认页入口、返回按钮、标记、横栏、操作条、手势、SPEC、Decision_log、`Scripts/`、`ci.yml` 一字未动。**

## v1 闸门 A 的处置

v1 的 R0 结论（执行端①）：`PHAssetResource` 无公开字节属性，三条候选途径各有取舍，代价无法在本机核实 → 停。H43 真机探针 `099.txt` 取回数据后，技术负责人按类型分派定案，**v1 的闸门 A 已解除**。

| v1 未决项 | v2 定案与依据 |
|---|---|
| 用哪条途径取字节数 | **按类型分派、无数值阈值**（④ 2026-08-28，依 H43①） |
| 已编辑照片的 URL 途径是否可信 | **不可信**。H43 病理反例 `CCE34A1A`：URL 途径 7,485 B，实际当前版本 3,899,648 B——相差 520 倍。该类改走 `.fullSizePhoto` 资源 |
| 视频 / 未编辑照片的 URL 途径 | **可信**。H43 视频 14/14、未编辑照片与 LivePhoto 35/35 逐字节精确 |
| 「占用空间」的语义 | **当前版本**（Decision_log 第 130 条④）。`.fullSizePhoto` 的语义即当前版本 |
| 单张显示口径 | KB / 一位小数 MB / 一位小数 GB（第 130 条④），由 IC-099b 已交付的 `S2AssetVolumeFormatter` 承担 |
| v1 报的「规格示例 2.4 MB 与 S3 口径矛盾」 | 已由第 130 条勘误对齐，本卡按新口径实装 |

## R4：取数路线分派、缓存与异步管线

### 分派表（`S2AssetVolumeRouter.route(mediaKind:isEdited:)`，纯函数）

| 资产 | 路线枚举 | 实现 | H43 依据 |
|---|---|---|---|
| 视频（未编辑） | `.videoAssetURL` | `requestAVAsset` → `AVURLAsset.url` 文件属性 | 14/14 逐字节精确 |
| 视频（已编辑） | `.videoAssetURL` | 同上 | 同上 |
| 未编辑照片 / LivePhoto | `.contentEditingInputURL` | `requestContentEditingInput` → `fullSizeImageURL` 文件属性 | 35/35 精确 |
| 已编辑照片 / 已编辑 LivePhoto | `.fullSizePhotoResource` | `.fullSizePhoto` 资源 `requestData` 流式累加 | URL 途径病理反例；该类读取实测 1.6～3.2 ms |

**失败降级**：`.fullSizePhoto` 缺失、任一路出错、请求被取消、iCloud 不可得（`PHContentEditingInputResultIsInCloudKey` / `PHImageResultIsInCloudKey`）一律返回 `nil` → 副行只显示 `{序号}/{总数}`，**不显示大小、不显示占位符**。全部路径 `isNetworkAccessAllowed = false`。

### 缓存与异步（`S2AssetVolumeStore`）

- `resolved: [String: Int64?]`——值为 `nil` 表示**已解析且失败**，同样不再重复发起。写入用 `updateValue(_:forKey:)` 而非下标赋值，避免「值类型本身是 `Int64?`」时下标赋值被读成删除键。
- `requestIfNeeded` 只在「未解析且不在途」时发起；在途集合 `inFlightAssetIDs` 防并发重复。
- 对外取值 `byteCount(for:)` **按 `assetID` 索引**——切资产时读到的是新资产的条目（未取数即 `nil`），**结构上不可能显示上一张的值**。
- 缓存只在内存，随 S2View 的 `@StateObject` 实例释放（会话级）。
- 视图侧由 `.task(id: machine.currentAssetID)` 触发，切资产自动重新触发。

## R1 / R2 / R3

**R1 纯函数**（`S2TopBarInfoPresentation`）：

- `dateText(creationDate:now:calendar:)`——当年 `M月d日`、非当年 `yyyy年M月d日`；`creationDate == nil` 返回 `nil`，**主行整行不显示**（v1 卡内④取定，不引入新文案）。
- `subtitleText(currentIndex:totalCount:byteCount:)`——`{序号}/{总数} · {占用空间}`；`byteCount` 为 `nil` 或负值时退化为 `{序号}/{总数}`。口径调用 IC-099b 已交付、IC-101 移入独立文件的 `S2AssetVolumeFormatter`，**未复制第二份格式逻辑**。

**R2 两行布局**：顶部中部由 `Text(序号)` 单件替换为 `topInfoArea`（主行 + 副行的 `VStack`）。**返回按钮与确认页入口一字未动**；`S2OverlayLayout.topElementFrames` 的三帧几何模型未动（IC-075 G104 等顶部门禁不受影响）。

**R3 String Catalog**：追加 3 个 key，全部被产品源码引用（扫描器 key ↔ 引用双向齐全，退出码 0）：

| key | zh-Hans | 说明 |
|---|---|---|
| `s2.top.date_format.current_year` | `M月d日` | 当年日期格式串 |
| `s2.top.date_format.other_year` | `yyyy年M月d日` | 非当年日期格式串 |
| `s2.top.position_with_volume` | `{current}/{total} · {volume}` | 副行含大小时的模板（分隔为空格 + U+00B7 + 空格） |

既有 `s2.top.position` = `{current}/{total}` **复用**为无大小分支，未改值。`export-format.md` 未动。

**为什么日期格式串入了目录**：v1 卡写「日期/数字为数据派生值，不入目录」——那指的是**渲染出来的日期与数字**，本卡确实没把它们入目录。入目录的是**格式串本身**，它属规格锁定的显示格式（v16 决策 35 原文规定「M月d日」/「yyyy年M月d日」），不由实现自行决定。若写成源码里的中文字面量会被硬编码扫描器判为残留，而本卡范围外不许改 `Scripts/`；入目录既满足扫描器，也让格式可被审阅。**这是本卡的一处判断，请技术负责人确认。**

## 逐条验收门禁

| 门禁 | 结果 | 证据 |
|---|---|---|
| **G225** C1～C5 通过 | 满足① | 六项测试函数名与 CI 通过行见下表；C5 见「既有门禁」 |
| **G226** CI success、真实退出码 0、XCTest 0 失败、计数算式、IPA 重下一致、本地三项门禁 0 | 满足① | 见「CI 与本地门禁」 |

### C1～C5 逐项（CI #173 全部 passed）

| 项 | 测试函数 | 断言要点 |
|---|---|---|
| **C1** 分派四行全覆盖 | `testIC099v2C1VolumeRouteDispatchCoversAllFourRows` | 视频 ×2 → `.videoAssetURL`；未编辑照片 / LivePhoto → `.contentEditingInputURL`；已编辑照片 / LivePhoto → `.fullSizePhotoResource`；枚举恰 **3** 条 |
| **C1 续** 失败降级 | `testIC099v2C1FailureDegradesToPositionOnly` | `byteCount == nil` → `3/128`；负字节数同样降级 → `1/1`；**不出现占位符** |
| **C2** 缓存 | `testIC099v2C2StoreFetchesEachAssetAtMostOnce` | 成功与失败各一，重复请求后 `requestCount == 2`，请求序列恰 `["asset-1","asset-2"]` |
| **C3** 三态副行 | `testIC099v2C3SubtitleReflectsPendingFailureAndAssetSwitch` | 未就绪 `1/2` → 就绪 `1/2 · 2.4 MB` → **切到未取数资产读到 `nil` 而非上一张的值**，副行 `2/2` → 就绪 `2/2 · 324 KB` |
| **C4** 日期 | `testIC099v2C4DateTextCoversYearBoundaryAndNil` | 当年 `8月27日`；当年元旦 `1月1日`（月日均不补零）；跨年前一日 `2025年12月31日`；老照片 `2011年3月5日`；`nil` → 主行不显示 |
| **C4 续** 副行原文 | `testIC099v2C4SubtitleTextUsesSlashAndMiddleDot` | `3/128 · 2.4 MB` 逐字符相等；分隔为空格 + `U+00B7` + 空格；不含 ` / `；三档口径六个用例与 IC-099b P1 同源 |
| **C5** 既有门禁 + 099b/101 断言 + S3 零 diff | 既有 508 项**一字未改**全过（`git diff 3b7d50e..HEAD -- PhotoCleanupMVETests/` 为 **278 增 0 删**）；`git diff main..HEAD -- Core/S3StateMachine.swift S3StateMachineTests.swift VolumeFormattingTests.swift` **无输出** | 见 CI 514/0 |

### CI 与本地门禁

| 项 | 值 |
|---|---|
| 工作流 | `iOS 构建与自验`，run **#173**（id 33081195895） |
| 被测提交 | `968998579306fc1a4be861f783a49a3211987114` |
| 结论 | **success**，9 步全 success |
| XCTest | **Executed 514 tests, with 0 failures (0 unexpected)** in 31.047 (34.549) seconds |
| 计数算式 | 508（IC-101 后基数）+ 6（本卡新增）− 0 = **514** ✅ |
| 真实退出码 | **0**（`set -o pipefail` + `exit "$test_status"`，步骤 6 conclusion = success） |
| IPA 字节数 | **836171** |
| IPA SHA-256 | `454342c72ec64735a139b6aec71e742aa8773d1e0238324049b6bbeba0788044` |
| 本地重下复核 | `gh run download` 取 `PhotoCleanupMVE-unsigned-968998579306`，本地 `stat` = **836171**、`sha256sum` = `454342c7…8044`，**与 CI 报告值逐字符一致** ✅ |
| `Scripts/selfcheck.ps1` | 退出码 **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | 退出码 **0** |
| `git diff --check` | 退出码 **0** |
| CI 使用次数 | **1 / 3** |

**注**：本分支已含 IC-101，因此 CI #173 用的是**新版** `ci.yml`（错误摘录含产品目录）。本次全绿，该扩展仍未被真实产品编译错误命中——IC-101 报告里的「待自证」保持未覆盖。

### 闸门核对

| 闸门 | 触发 | 说明 |
|---|---|---|
| **A** 分派须改图片请求策略 / 节流 / `AssetSizeScanner` 的 S3 语义 | 否 | `S2TemporaryPhotoImageStrategy` 与产品的 `PHImageManager.requestImage*` 调用点一字未动；`AssetSizeScanner`（S3 用，多资源求和）一字未动，`AssetVolumeService` 与它无调用关系 |
| **B** 任一既有门禁失败 | 否 | 514/0 全过；测试文件 **278 增 0 删**，既有断言一行未改 |
| **C** 新增标定参数、改出厂值或 `schemaVersion`；KVC | 否 | `S2CalibrationConfiguration` 未加字段、出厂值未改、`schemaVersion` 仍为 **4**；全仓库无 `value(forKey:` 的资源尺寸访问 |

## 取定与占位值登记

### v1 卡内取定（④，本卡实装）

1. **`creationDate == nil` 时主行不显示，仅显示副行**，不引入新文案。→ `dateText` 返回 `nil`，`topInfoArea` 用 `if let` 整行不渲染。
2. **占用空间取当前版本字节数** → 由 v2 的分派表承担（v1 取定里「照片取原图资源」与「含系统编辑版本时取当前版本」的内部冲突，已被第 130 条④「当前版本语义」统一，本卡按当前版本实装）。
3. **字体 / 字号 / 颜色为视觉稿前占位样式**，不进标定参数、不进规格。

### 占位样式登记（卡内要求）

| 元素 | 本卡所用样式 | 性质 |
|---|---|---|
| 主行（拍摄日期） | `.font(.caption)` + `.foregroundStyle(.primary)` | 视觉稿前占位，④ 可改 |
| 副行（序号 · 占用空间） | `.font(.caption2)` + `.foregroundStyle(.secondary)` | 视觉稿前占位，④ 可改 |
| 两行间距 | `VStack(spacing: 0)` | 视觉稿前占位，④ 可改 |
| 行数限制 | 两行各 `.lineLimit(1)` | 防止长文案挤压顶部三件的既有几何 |

**均为系统字体与语义色，不进 `S2CalibrationConfiguration`、不上参数面板、不进规格。** `schemaVersion` 仍为 **4**。

未定项 7（顶部各元素字体、字号与精确位置属视觉稿范围）**未触碰**——本卡只做结构实装，样式全是占位。

## 人工判定项

**H42（v1 原文 + 两项加测），保留给 Lynn 真机判定，本报告不代为下结论。** 装本卡 CI #173 的包（IPA 836171 字节、SHA-256 `454342c7…8044`）。

| 判定项 | 说明 |
|---|---|
| 抽三张照片一段视频对照系统「信息」页 | 日期文本（**含一张非当年老照片**）、序号、大小量级 |
| **加测一张已编辑照片** | 大小应为**编辑后当前版本**量级，**不得出现 KB 级病理值**（H43 反例是 7,485 B ≈ 7 KB） |
| **加测新照片刚进入时** | 副行先只有序号，稍后补出大小；**翻页不串张** |
| 明暗两模式可读 | 占位样式用的是语义色，理论上跟随，仍需实看 |
| 拖横栏期间顶部不可点 | 既有 `.disabled(machine.touchSequenceOwner != .none)` 未动 |
| 无回归抽查 | 翻页 / 标记 / 双击 / 捏合 / `V` 显隐 / sheet |

## 真机未覆盖项清单

1. **三条取数路线在产品路径上零真机验证**——H43 验的是 IC-099b 的**探针**实现，本卡的 `AssetVolumeService` 是另一份代码（返回契约不同，见「发现」第 1 条）。路线选择的正确性有 H43 背书，但这份实现本身只有夹具级断言（用假 provider），**真实 PhotoKit 调用未跑过**。H42 的「已编辑照片加测」是第一次真机验证。
2. **`.fullSizePhoto` 缺失的降级路径未覆盖**——夹具里用假 provider 返回 `nil` 模拟，真机上什么情况下会缺失、缺失后是否真的只显序号，未验证。
3. **iCloud-only 资产未覆盖**——禁网络下三条路线各自的失败表现（是快速失败还是挂起）无数据；若挂起，副行会长期停在只显序号。
4. **翻页速度与取数竞态未覆盖**——快速连翻时 `.task(id:)` 的取消与重入、缓存写入顺序，只有真机能判。夹具是串行的。
5. **日期格式在真机 locale 下的输出未验证**——夹具用 `zh_Hans_CN` 日历显式构造；真机若系统语言非中文，`DateFormatter` 用目录里的中文格式串会输出中文月日字样。App 目前只有 zh-Hans 一种本地化，属预期，但未实看。
6. **占位样式的可读性与顶部三件的横向挤压未验证**——两行 `.caption`/`.caption2` 在窄机型上是否会挤到返回按钮或确认页入口，只有真机能看。

## 发现但未处理的问题（按纪律只报告不修）

1. **`AssetVolumeService` 与 IC-099b 的 `AssetSizeProbeService` 有三处 PhotoKit 调用外形重复**（contentEditingInput、requestAVAsset、requestData 各一）。没有合并是因为返回契约不同：探针要「两条路线各自的字节数 + 失败原因七分类」用于取证，产品路径只要「当前版本的一个 `Int64?`」；而且探针的数据路线取的是**原始**主资源，本卡取的是 `.fullSizePhoto`（当前版本），**语义相反**，强行共用反而会埋坑。若日后要收敛，应先抽出一层「给定资源 → 字节数」的最小共用件，而不是共用整条路线。
2. **日期格式串入 String Catalog 是本卡的判断**（理由见 R3 节）。若技术负责人认为格式串不该进目录，替代方案是给 `Scripts/scan-hardcoded-user-visible-strings.ps1` 加一条与 IC-101 同类的路径豁免——那属 `Scripts/`，本卡范围外。
3. **`.task(id:)` 只在当前资产上取数，没有预取相邻页**。翻页时新资产的大小要等一次异步往返才出现（H42 的加测项正是看这个）。是否要预取 ±1，属产品体验决策，卡内未写，未自行决定。
4. **缓存无上限**。会话内浏览过的每个资产都会留一条记录（`String` + `Int64?`），一次会话上千张也只有几十 KB，但没有淘汰策略。卡内只要求「会话级」，未做 LRU。
5. **顶部信息区两行没有无障碍标签合并**。主行与副行是两个独立 `Text`，VoiceOver 会分别朗读；系统相册是合并成一条朗读的。卡内未提，未自行决定。
6. **扫描器的 key 提取正则要求键名字面量紧跟调用括号**（`L10n\.text\(\s*"…"`）。本卡最初把三元判断写进调用参数里，两个 key 立刻被判成「目录里有、源码没引用」；另外注释里写了一段含中文字面量的示例代码，也被当成真实调用与硬编码残留。两处都已改写。**这条规则没有写在任何文档里**，下一个加 key 的人会重踩，值得记进 CLAUDE.md 陷阱节——属 CLAUDE.md，本卡范围外。

## 完成后动作

**完成即停，等 H42。** 未合并主干，未动冻结三链。
