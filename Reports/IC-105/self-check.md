# IC-105 自验报告（测试辅助类并发保护修复，main 恢复绿）

## 结论（先行）

**本卡通过。`main` 已恢复绿。采用的是卡内的回退方案（NSLock），不是首选方案（`@MainActor`）。**

- **G243 通过**①：开工时 `git status --porcelain` 空；`main` tip = `7e786f420aba3650b05f3058d943dedec3fe0b0a`，与卡规定值相符。
- **G244 通过**①：代码 commit `git diff --name-only` 恰为 `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` 一个文件；`git diff --name-only -- PhotoCleanupMVE/`（产品目录）**空**。
- **G245 通过**①：CI **#177 success**，被测 `46f7174b2475c3cbd06bb9af73b9af1f109bfde4`，9 步全 success，**真实退出码 0**，`Executed 519 tests, with 0 failures (0 unexpected) in 25.808 (34.994) seconds`；IPA **836638 字节**、SHA-256 `e5cfb0d183b83820c74ac41a72bc8e41bfa0ecfd522c030a8b96673c540a4b2c`。
- **G246 分叉闸门：触发过一次**。首选方案在 CI **#176 编译不过**（10 条错误，全部为 `@MainActor` 标注引发的跨隔离访问）。**该结果同时落入卡内第 2 步「首选在 CI 编译不过 → 用回退方案」与 G246(b)「编译错误 → 停」两条相反条款**；本卡按第 2 步执行回退，理由与矛盾原文见「G246 条款冲突与取舍」一节，**请决策会话复核该取舍**。
- **G247 通过**①：`schemaVersion == 4` 未变；冻结三链 `b368a6c` / `6736f1e` / `a7cc1ec` 引用未动；`<top>/CLAUDE.md` 仅第七节基线行一处 hunk。

**根因假设经实测确认**：卡内 ① 归因（`requestedAssetIDs` 并发 append 丢更新）成立——加锁后 519 项 0 失败，`:7903` / `:7909` 两条断言恢复通过，且未引入任何新失败。

**人工判定：无。** 本卡零产品代码变更、零用户可见行为变更，不产生真机判定项。

## 输入与边界

| 项 | 值 |
|---|---|
| 开工时 `git status --porcelain` | 空（纪律 8 检查通过） |
| 继承提交 | `7e786f420aba3650b05f3058d943dedec3fe0b0a`（IC-102 报告提交），实测相符 |
| 目标分支 | `main` |
| 首选方案 commit | `44ca58ca19c1ecd04c52a2de057b64214da8ae9e`（CI #176 failure） |
| **最终 fix commit** | **`46f7174b2475c3cbd06bb9af73b9af1f109bfde4`**（CI #177 success） |
| CI 预算 | 2 次（首选 1 + 回退 1），**已用 2 次** |
| 范围边界 | 只改 `PhotoCleanupMVETests/S2CalibrationHarnessTests.swift` 中卡内列名的两个 helper 类；产品目录零 diff |

## 开工前的静态核查（推首选方案之前）

推 CI 之前先核对了首选方案的可行性前提，结论是**预判其编译不过**，但仍按卡执行首选（卡明文规定回退「仅当首选在 CI 编译不过时用」，且预算正为此留）：

| 核查项 | 结果（①，本机可核） |
|---|---|
| `S2CalibrationHarnessTests`（`:207`）是否 `@MainActor` | **否**，`final class S2CalibrationHarnessTests: XCTestCase {`，无属性 |
| 两个 helper 的全部使用点所在方法 | 5 处 init + 6 处属性读，共 11 处，**全部**位于非隔离的同步测试方法内（`func testXxx() {`，非 `async`、无 `@MainActor`） |
| 两个协议要求 | `S2AssetVolumeProviding.byteCount(assetID:) async`、`S2AssetSizeProbing.measure(assetID:) async`，**均为非隔离 `async`**（`@MainActor` 类可以见证 `async` 要求，协议侧不是障碍） |
| 工程并发设置 | `SWIFT_VERSION = 5.0`；pbxproj 中**无** `SWIFT_STRICT_CONCURRENCY`、**无** `SWIFT_DEFAULT_ACTOR_ISOLATION` → 默认隔离为 nonisolated，Swift 5 语言模式下跨隔离同步访问是**错误**而非警告 |

预判（当时标注为③，因本机无 Xcode 无法编译验证）：加 `@MainActor` 后这 11 处会全部报错。**CI #176 实测与预判完全一致**，预判由此升为①。

## 首选方案与 CI #176

**改动**：`CountingAssetVolumeProvider`（`:8979`）与 `CountingAssetSizeProber`（`:9000`）两个类声明前各加一行 `@MainActor`，方法体未动。1 file changed, **2 insertions(+), 0 deletions**。本地三项门禁退出码全 0。

| 项 | 值 |
|---|---|
| run 编号 | **#176** |
| run id | `33129797517` |
| 被测提交 | `44ca58ca19c1ecd04c52a2de057b64214da8ae9e` |
| 起止 | 2026-08-28T00:27:48Z → 00:29:10Z |
| 结论 | **failure** |
| 失败步骤 | 步骤 6「运行 XCTest」（步骤 1–5 全 success） |
| 真实退出码 | 非 0（步骤 6 failure）。**具体数值未取到**：check-run 注解 10 条上限被编译错误占满，未含 `Process completed with exit code` 行；job 日志下载在 4 次重试内均因网络失败。按纪律不复述未取到的数字。 |
| XCTest | **未执行**（编译阶段即失败，无 `Executed …` 摘要） |
| 步骤 7/8 | skipped；run artifacts `total_count = 0`，无 IPA |

10 条编译错误原文（全部，注解上限即为 10）①：

```
:7903:33: error: main actor-isolated property 'requestedAssetIDs' can not be referenced from a nonisolated autoclosure
:7885:24: error: call to main actor-isolated initializer 'init(byteCounts:)' in a synchronous nonisolated context
:7792:31: error: main actor-isolated property 'measureCount' can not be referenced from a nonisolated autoclosure
:7780:22: error: call to main actor-isolated initializer 'init()' in a synchronous nonisolated context
:7753:31: error: main actor-isolated property 'requestedAssetIDs' can not be referenced from a nonisolated autoclosure
:7752:31: error: main actor-isolated property 'measureCount' can not be referenced from a nonisolated autoclosure
:7741:22: error: call to main actor-isolated initializer 'init()' in a synchronous nonisolated context
:7736:31: error: main actor-isolated property 'measureCount' can not be referenced from a nonisolated autoclosure
:7729:31: error: main actor-isolated property 'measureCount' can not be referenced from a nonisolated autoclosure
:7721:22: error: call to main actor-isolated initializer 'init()' in a synchronous nonisolated context
```

**全部 10 条都是 `@MainActor` 标注本身在既有使用点上引发的跨隔离访问错误**，行号与开工前核查列出的 11 处使用点一一对应（`:7909` 未单列，同函数内前一错误已使该表达式不再单独诊断）。**没有任何一条**指向竞态本身、产品代码、或其他测试。

## G246 条款冲突与取舍（须复核）

CI #176 的结果同时命中卡内两条给出**相反指示**的条款：

- **范围内第 2 步**：「**回退方案（仅当首选在 CI 编译不过时用，计入预算）**：改为在两个 helper 内用 `NSLock` 保护 `requestedAssetIDs` 的写入与读取，公开接口与断言不变。」
- **G246(b)**：「**新签名**（值断言失败、其他测试失败、**或编译错误**）→ **停，报告实际输出，不得触碰产品代码，不得开始 IC-104。**」

**本卡按第 2 步执行回退**，三条理由：

1. **G246 的引导语是「若 CI 仍失败」**——「仍」指向 #175 既有的竞态失败模式的延续。编译错误意味着修复根本没能运行，属另一类别，而第 2 步正是专门针对这一类别写的。
2. **若任何编译错误都触发 G246(b)，第 2 步的回退触发条件将永不可达**，「预算 **CI 2 次（首选 1 + 回退 1）**」与本下发单收尾第 1 项要求报告「**采用首选还是回退方案**」两处都会成为空文。这两处都预设了回退在本轮是可达的。
3. **本次编译错误 100% 可归因于卡自身规定的那一处标注**（10/10 条），不属于 G246(b) 意在拦截的「出现了别的意外」。

**风险与对冲**：若决策会话认为 G246(b) 应当优先，则本卡的第二次 CI 属越权动作。对冲是——回退方案是卡内**明文写定**的方案，改动**仅限测试目录**、产品目录零 diff、公开接口与全部断言零变化，且结果为 519/0 全绿，可完整回退（`46f7174` 单独 revert 即回到 `44ca58c`）。取舍连同本节原文一并上报，**不隐藏、不代为定论**。

## 回退方案与 CI #177

**改动**：先删去两行 `@MainActor`（此时文件 blob 回到 `c15cf4a6ee236a72125e18b29b1fed672eefb97f`，即 IC-102 v2 交付态，本机复核相符①），再对两个 helper 施加 NSLock 保护。

两个类各自：

- 记录数组改为私有 `recordedAssetIDs`，新增 `private let recordLock = NSLock()`；
- `requestedAssetIDs` 改为**只读计算属性**，读取过锁（`lock()` / `defer { unlock() }`）；
- `byteCount(assetID:)` / `measure(assetID:)` 内的 append 过锁；
- 其余方法体、返回值构造、`init` 签名一字未改。

**公开接口逐项核对（零变化）**：

| 成员 | 改动前 | 改动后 | 外部契约 |
|---|---|---|---|
| `requestedAssetIDs: [String]` | `private(set) var`（存储） | `var`（只读计算） | 同为**外部只读的 `[String]`**，不变 |
| `requestCount: Int` | `requestedAssetIDs.count` | 同左 | 不变 |
| `measureCount: Int` | `requestedAssetIDs.count` | 同左 | 不变 |
| `init(byteCounts:)` | 显式 | 显式，签名未改 | 不变 |
| `CountingAssetSizeProber()` | 隐式默认 init | 仍为隐式默认 init（新增属性均有默认值） | 不变 |

**断言零改造**：6 处消费点（`:7729` `:7736` `:7752` `:7753` `:7792` `:7903` `:7909`）**一字未改**，5 处构造点未改。**测试计数 519 保持不变**（新增 0 / 改造 0 / 删除 0）。

| 项 | 值 |
|---|---|
| run 编号 | **#177** |
| run id | `33130464724` |
| html_url | `https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/33130464724` |
| 被测提交 | `46f7174b2475c3cbd06bb9af73b9af1f109bfde4` |
| 分支 / 事件 / attempt | `main` / push / 1 |
| 起止 | 2026-08-28T00:40:28Z → 00:45:44Z |
| 结论 | **success** |
| **真实退出码** | **0**（`ci.yml:52` `set -o pipefail`、`:82` `exit "$test_status"`；步骤 6 success ⇒ `test_status == 0`） |
| **XCTest** | **`Executed 519 tests, with 0 failures (0 unexpected) in 25.808 (34.994) seconds`** |
| **IPA 字节数** | **836638** |
| **IPA SHA-256** | **`e5cfb0d183b83820c74ac41a72bc8e41bfa0ecfd522c030a8b96673c540a4b2c`** |
| artifact | `PhotoCleanupMVE-unsigned-46f7174b2475`（id `9670136752`，zip 包 836808 字节） |

步骤逐条：

```
step 1 [success] Set up job
step 2 [success] 检出源码
step 3 [success] 显示 Xcode 环境
step 4 [success] 运行结构自验
step 5 [success] 扫描用户可见硬编码字符串
step 6 [success] 运行 XCTest
step 7 [success] 构建未签名应用
step 8 [success] 上传可下载的未签名 IPA
step 9 [success] Complete job
```

**IPA 复核说明**：上表字节数与 SHA-256 取自 CI 内「未签名 IPA 校验」步骤的注解（CI 侧实算值，①）。本机**未重下复核**——卡内 G245 只要求「登记」，且本机 blob 下载在本轮网络下反复失败；另据既有结论 IPA 归档不可复现（同源码树字节数相同而 SHA-256 不同，IC-094/097 证据），重下哈希本就不能用作跨运行同一性判据。

## 根因确认

卡内 ① 归因链：`S2AssetVolumeStore.requestIfNeeded`（`S2TopBarInfoPresentation.swift:79`）以 `Task { @MainActor }` 发起取数，协议方法 `byteCount(assetID:) async` 非隔离 → 两个在途资产的调用在并发执行器上同时运行 → 无保护的 `requestedAssetIDs.append` 丢更新。

**本卡实测确认**①：仅对该数组加锁（产品代码零改动），`:7903` 与 `:7909` 两条断言恢复通过，519 项 0 失败，且未引入任何新失败。归因成立，**未被推翻**。

`CountingAssetSizeProber` 为同型缺陷（同为 `final class` + 非隔离 `async` 方法 + 无保护数组），本卡按卡一并加锁；其 4 处断言（`:7729` `:7736` `:7752` `:7753` `:7792`）本轮与此前均未失败，属**预防性修复**，无失败史可佐证其曾触发（②）。

## 逐条闸门结果

| 闸门 | 判定 | 依据 | 对应命令/测试 |
|---|---|---|---|
| **G243** | 通过 | 工作树空；`main` = `7e786f4…b0a` | `git status --porcelain`、`git rev-parse main` |
| **G244** | 通过 | 两次代码 commit 均恰改一个测试文件；产品目录零 diff | `git diff --name-only`、`git diff --name-only -- PhotoCleanupMVE/` |
| **G245** | 通过 | CI #177 success、退出码 0、**519/0**、IPA 836638 / `e5cfb0d1…4b2c` 已登记 | CI #177；`testIC099v2C2StoreFetchesEachAssetAtMostOnce` 等 519 项 |
| **G246** | 触发 (a 路径之外的编译分支)，按第 2 步走回退 | #176 编译不过，10/10 错误归因于 `@MainActor` 标注；见「G246 条款冲突与取舍」 | CI #176 注解 |
| **G247** | 通过 | `schemaVersion == 4`；冻结三链引用不变；CLAUDE.md 仅基线行一处 hunk | `S2Calibration.swift:118`、`git rev-parse feature/ic-089/091/092` |

## 本地门禁（真实退出码）

两次代码改动各自跑满三项，全部退出码 **0**：

| 门禁 | 首选方案（`44ca58c`） | 回退方案（`46f7174`） |
|---|---|---|
| `Scripts/selfcheck.ps1` | **0** | **0** |
| `Scripts/scan-hardcoded-user-visible-strings.ps1` | **0** | **0** |
| `git diff --check` | **0** | **0** |

两次均为：目录条目 177 / 产品源码引用 key 177 / 用户可见硬编码残留 0；「不少于 189 项测试的数量门禁」符合。

## 冻结三链与出厂值

| 项 | 值 | 判定 |
|---|---|---|
| `feature/ic-089-nx-edge-bounce` | `b368a6caee846e664391b0620350395bfe6fbc7f` | 未触碰 |
| `feature/ic-091-nx-midgesture-handoff` | `6736f1e3ebf2a3fd9a0c00f1bcd2c83f81dec74d` | 未触碰 |
| `feature/ic-092-nx-window-follow` | `a7cc1ec727a3a493f5263e688a316cbf4c743562` | 未触碰 |
| `S2CalibrationConfiguration.schemaVersion` | `4`（`S2Calibration.swift:118`） | 未变更（本卡零出厂值变更） |

## CLAUDE.md 基线行

已按卡第 5 步更新 `<top>/CLAUDE.md` 第七节基线行，**仅该行语义、一处 hunk**：新基线 = 本卡报告提交后的 tip，被测 = `46f7174b2475c3cbd06bb9af73b9af1f109bfde4`，CI #177，XCTest 519 项 0 失败。同时把 IC-102 遗留的「现载 `ef9d46a` 与真实 tip 不一致」一并归零。hunk 原文见 `change-list.md`。

## 人工判定项

**无。** 本卡改动全部位于 `PhotoCleanupMVETests/`，产品目录零 diff，无用户可见行为、几何或手势语义变化，不产生真机判定项。本卡**不代 Lynn 下任何真机结论**。

## 发现但未处理的问题（只报告不修）

1. **首选方案（`@MainActor`）在本工程当前配置下结构性不可行**——不是本卡的偶发失败：只要 `S2CalibrationHarnessTests` 本身不是 MainActor 隔离，给任何被非隔离同步测试方法直接构造/读取的 helper 加 `@MainActor` 都会重演 #176。若日后要走 `@MainActor` 路线，需连带处理测试类或使用点的隔离，属另卡范围。
2. **同型风险尚存**：本卡只按卡处理了列名的两个类。其余测试辅助类是否存在「非隔离 `async` 方法 + 无保护可变状态」的同型结构，本卡**未做全量扫描**（卡范围外明确禁止「给未列名的类型加并发标注」）。卡内上游证据称「全文件扫描确认含 async 方法的辅助类仅此两个」（决策会话①），本卡未复核该扫描。
3. **CI #176 的真实退出码数值未取到**：注解 10 条上限被编译错误占满，job 日志下载 4 次重试均失败。已如实标注，未以推断值代替。
4. **本机网络**：`git push` 三次均需 `-c http.proxy=http://127.0.0.1:7890`（直连 `schannel: failed to receive handshake`）；`gh api` 带代理与直连均间歇 EOF，需 2–4 次重试；job 日志（`actions/jobs/{id}/logs`）本轮完全取不到。与 CLAUDE.md 第五节记载方向相反，该节已注明「两者偶有互换」。
