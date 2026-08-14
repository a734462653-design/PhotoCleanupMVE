# IC-20260814-044 自验证报告

## 一、任务与结论

- 任务 ID：`IC-20260814-044-ci-gate-generalize`
- 任务基线：`eb9784e51d8f7aa13d002da4f8725a3fd7324125`
- 基线分支：`main`
- 基线工作树：洁净，未跟踪条目为 0
- 目标：把 CI 从 `IC-20260812-024` 卡专用门禁切换为通用门禁，并把测试数量和产品源码清单改为只拒绝倒退的单调断言

本卡只修改 `.github/workflows/ci.yml`、`Scripts/selfcheck.ps1`，并新增本报告。没有修改 Swift 源码、测试、历史专项自验脚本、SPEC 或既有报告，也没有删除 `Scripts/` 下文件。

本地静态门禁已经通过；受验提交 `c9d54c959367cb9cd9c79758ef4bce319847f49c` 触发的 `macos-15` CI #21 也已全绿。CI 实际执行 203 项 XCTest，0 失败、0 unexpected；Release 构建、未签名 `.app` 门禁、IPA 生成与完整性校验及产物上传均通过。

## 二、CI 门禁切换

改动前，CI 的“运行结构自验”步骤执行：

```powershell
./Scripts/verify-IC-20260812-024.ps1 -允许待回填CI
```

该脚本属于历史任务证据，包含 `IC-20260812-024` 的固定测试数、固定产品路径、专项测试名、旧报告内容和旧任务范围断言，不能作为后续开发的通用门禁。

改动后，CI 显式执行两个通用入口：

```powershell
./Scripts/selfcheck.ps1
./Scripts/scan-hardcoded-user-visible-strings.ps1
```

`selfcheck.ps1` 内原有的硬编码扫描调用仍然保留；CI 再显式调用一次扫描脚本，是为了让工作流本身清楚展示两类通用门禁。重复执行不会删除或放宽任何检查。

`git diff --unified=0 -- .github/workflows/ci.yml` 只有上述门禁调用变化。其后的 `bash Scripts/test-xcode.sh`、Release `iphoneos` 构建、`CODE_SIGNING_ALLOWED=NO`、`CODE_SIGNING_REQUIRED=NO`、`codesign` 反向检查、`_CodeSignature` 与 `embedded.mobileprovision` 拒绝、IPA 普通文件与非空校验、`unzip -tq`、SHA-256、固定提交的 `actions/upload-artifact` 及上传参数均保持原样。

## 三、断言形式前后对照

| 检查项 | 改动前的有效 CI 断言 | 改动后的通用 CI 断言 | 当前证据 |
|---|---|---|---|
| CI 门禁入口 | CI 调用卡专用 `verify-IC-20260812-024.ps1`，再由它调用 `selfcheck.ps1` | CI 直接调用 `selfcheck.ps1` 与硬编码扫描脚本 | 工作流中已无 `verify-IC-20260812-024.ps1` 调用，两个通用入口各有一处显式调用 |
| XCTest 方法总数 | `实际数量 == 189`，增加测试也失败 | `实际数量 >= 189`，只在低于既有通用基线时失败 | 当前静态计数为 203，`203 >= 189`，自检退出码 0 |
| 产品 Swift 源码清单 | 卡专用脚本要求当前产品路径集合与旧任务基线集合完全相同 | `当前产品 Swift 路径集合 ⊇ 既有 16 文件基线集合`；逐个拒绝基线文件缺失，不比较总数 | 当前为 17 个，16 个基线文件全部存在；新增的 `SessionStore.swift` 被允许，自检退出码 0 |
| Target 类型 | 卡专用脚本要求恰有应用与单元测试两个 product type，拒绝 XCUITest | 同一断言移入 `selfcheck.ps1`：target 数量仍为 2，必须包含应用与单元测试类型，并继续拒绝工程或共享方案中的 UI 测试引用 | 当前为 `application` 与 `bundle.unit-test`，无 XCUITest |
| 禁联网与账号能力 | `selfcheck.ps1` 扫描产品 Swift，拒绝 `URLSession`、`NWConnection`、`NetworkExtension`、`Alamofire`、`Moya`、`import Network`、`AuthenticationServices`、`ASAuthorization`、`StoreKit` | 原断言逐字保留 | 当前命中 0，自检退出码 0 |
| String Catalog 一致性 | 硬编码扫描要求目录可解析、源语言为 `zh-Hans`、每个 key 只有一个非空 `zh-Hans` 值，且源码引用 key 与目录 key 双向一致 | 原断言逐条保留；CI 另显式调用扫描脚本 | 目录 72 项、源码引用 72 项，双向一致，退出码 0 |
| 用户可见硬编码残留 | 残留数量必须为 0 | 仍必须为 0，没有改成上限或白名单放行 | 当前残留 0，退出码 0 |

单调性只用于会随正常开发增长的两项：测试方法总数和产品 Swift 文件清单。Target 类型、禁联网、String Catalog 双向一致及用户可见硬编码残留为 0 均未改成单调或容差形式。

## 四、通用门禁保留清单

除第三节明确改变方向的两项外，`selfcheck.ps1` 与其调用的硬编码扫描继续执行以下检查：

| 序号 | 保留的检查 | 断言强度 |
|---:|---|---|
| 1 | 必需交付文件存在 | 每个既有非产品源码文件必须是普通文件 |
| 2 | Bundle Identifier | 应用与测试 Bundle Identifier 必须保持既定值 |
| 3 | 工具链配置 | iOS 最低版本必须包含 `17.0`，Swift 版本必须包含 `5.0` |
| 4 | Target 类型 | target 必须且只能是应用与单元测试两类，共 2 个 |
| 5 | UI 测试禁入 | 工程不得出现 XCUITest product type、`XCUITest` target；共享方案不得出现 `UITest` 引用 |
| 6 | 工程源码引用 | 既有源码、测试及 `Localizable.xcstrings` 名称必须仍被工程引用 |
| 7 | Info.plist | 必须是合法 XML |
| 8 | CI 外部 Action 数量 | `uses:` 引用必须恰为 1 个 |
| 9 | CI 外部 Action 锁定 | 只允许 `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |
| 10 | CI XCTest、构建与打包字段 | XCTest 命令、关闭签名参数、IPA 路径、产物命名和全部上传参数必须存在 |
| 11 | 占位图 PNG | 文件长度必须足够且 8 字节 PNG 签名必须一致 |
| 12 | 占位图目录 | 语言条目必须且只能为 `zh-Hans`，且只能引用既定 PNG 文件 |
| 13 | 产品源码基线 | 既有 16 个产品 Swift 路径逐个必须存在；允许新增，不允许删除或改名既有项 |
| 14 | 产品禁联网 | 联网框架、类和 `import Network` 命中必须为 0 |
| 15 | 产品禁账号/商店能力 | AuthenticationServices、ASAuthorization、StoreKit 命中必须为 0 |
| 16 | L3 未定项 | 不得写死轮询窗口、采样间隔、稳定/启动阈值或基线时机 |
| 17 | S5 禁用标记 | 既定 S5 轮询实现标记命中必须为 0 |
| 18 | 调试入口唯一性 | `debugAssetLimit` 定义必须恰为 1，调用必须且只能引用该常量 1 次 |
| 19 | S3 已删除上限 | 已删除的数量上限实现标记命中必须为 0 |
| 20 | L3 阻断边界 | 必须存在显式阻断标记，且不得写入数值显示门槛 |
| 21 | XCTest 数量下限 | 测试方法不得少于 189；允许增加 |
| 22 | S3 可达映射 | 编号集合必须与既定三状态基线逐项相同 |
| 23 | S4 可达映射 | 可达单元格数量必须为 22 |
| 24 | S5 可达映射 | 原有可达单元格数量必须为 15 |
| 25 | S5 取消语义测试 | 5 个既定取消语义测试名必须逐个存在 |
| 26 | 硬编码扫描执行 | 扫描脚本必须存在且退出码必须为 0 |
| 27 | String Catalog 结构 | JSON 必须可解析，`sourceLanguage` 必须为 `zh-Hans`，每个 key 只能有一个非空 `zh-Hans` 值 |
| 28 | 用户可见字符串 | 含汉字的产品源码字面量、UI API 直接字面量和用户消息字面量不得形成未批准残留 |
| 29 | String Catalog 双向引用 | 源码引用的每个 key 必须在目录中，目录的每个 key 也必须被产品源码引用 |
| 30 | 用户可见硬编码总数 | 残留总数必须严格等于 0 |

历史卡专用脚本中的旧任务基线提交、旧报告文本、C34-093 至 C34-101 专项方法名和旧任务改动白名单属于历史证据，不是通用门禁；它们的脚本文件全部原样保留，只从 CI 调用链移除。

## 五、本地执行结果

### 5.1 改动前阻塞复现

在任务基线执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\selfcheck.ps1
```

结果：退出码 1；唯一失败为“XCTest 测试函数应为 189 个，实际为 203 个”。同一次执行中 String Catalog 与硬编码扫描已经通过，用户可见硬编码残留为 0。

### 5.2 改动后通用门禁

执行相同命令，结果为退出码 0。随后独立执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Scripts\scan-hardcoded-user-visible-strings.ps1
```

结果同样为退出码 0。

| 本地检查 | 结果 |
|---|---|
| XCTest 方法静态计数 | 203 |
| 测试文件数 | 9 |
| 产品 Swift 基线文件数 | 16 |
| 当前产品 Swift 文件数 | 17 |
| 当前新增于通用基线的产品文件 | `PhotoCleanupMVE/Core/SessionStore.swift` |
| Target 类型 | 应用 1、单元测试 1、XCUITest 0 |
| String Catalog 条目 | 72 |
| 产品源码引用 key | 72 |
| 用户可见硬编码残留 | 0 |
| `git diff --check` | 通过 |
| `selfcheck.ps1` 编码与换行 | UTF-8 BOM、仅 LF、末尾 LF |
| `ci.yml` 编码与换行 | UTF-8 无 BOM、仅 LF、末尾 LF |

203 项的分文件静态计数如下：

| 测试文件 | 方法数 |
|---|---:|
| `CollectionInvariantTests.swift` | 16 |
| `CoverageGapTests.swift` | 36 |
| `S3StateMachineTests.swift` | 22 |
| `S4StateMachineTests.swift` | 45 |
| `S5StateMachineTests.swift` | 45 |
| `SessionStoreTests.swift` | 14 |
| `SnapshotInvariantTests.swift` | 18 |
| `TransitionTableGuardTests.swift` | 1 |
| `VolumeFormattingTests.swift` | 6 |
| **合计** | **203** |

## 六、受保护文件 Git blob 证据

任务基线先对逐文件 `git hash-object` 结果按路径排序，再对“blob、制表符、路径、LF”清单计算 SHA-256。完成前使用相同算法复算；只有逐文件 blob 和路径集合全部相同，清单摘要才相同。

### 6.1 历史验证脚本

- 文件数：7
- 基线清单 SHA-256：`5ace7f1953c3e849e2b2388ebe0b7eba3586656f27e4f0bf3f47ad6ed5371469`
- 实现提交后清单 SHA-256：`5ace7f1953c3e849e2b2388ebe0b7eba3586656f27e4f0bf3f47ad6ed5371469`

| Git blob | 路径 |
|---|---|
| `2878c9937f28c17cfb512a1fba45e6a44dfad0a6` | `Scripts/verify-IC-20260812-010.ps1` |
| `d59ea127213bb409e840c58d28b61f34e84e4c40` | `Scripts/verify-IC-20260812-011.ps1` |
| `10ba37dce9556e4248c28f3ff391355dcb83bc43` | `Scripts/verify-IC-20260812-014.ps1` |
| `efd5fc0c687be254e8672b1c67c124c2ef54e967` | `Scripts/verify-IC-20260812-019.ps1` |
| `f191b52715f3744d1f3dbef3973b3617a6540a16` | `Scripts/verify-IC-20260812-021.ps1` |
| `480400926bbbc6e90001b9fe4044a11995204f3e` | `Scripts/verify-IC-20260812-023.ps1` |
| `20c8a7d155bf50fdac9e9bc23631c02f71357ab2` | `Scripts/verify-IC-20260812-024.ps1` |

### 6.2 全部 Swift 源码与测试

- 文件数：26
- 基线清单 SHA-256：`1f1d81f7551fe2b4464f634bd5b754ede9b738197841365f05fd112c4ab6b9a5`
- 实现提交后清单 SHA-256：`1f1d81f7551fe2b4464f634bd5b754ede9b738197841365f05fd112c4ab6b9a5`

| Git blob | 路径 |
|---|---|
| `3e4b26ad776fe4523d150a05b4d1e12b833dd546` | `PhotoCleanupMVE/App/CleanupCoordinator.swift` |
| `0a202742281fa73be5c1ce4e3e0a8f68df451023` | `PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift` |
| `eac7b0b084e21d8d018b8a110e54b154eb9f63b5` | `PhotoCleanupMVE/Core/AssetModels.swift` |
| `5b7918f7dfcafe60f4c19898345877c10b97b00d` | `PhotoCleanupMVE/Core/L10n.swift` |
| `37ec6960fa7e94de77e17863c473dfd7db31208e` | `PhotoCleanupMVE/Core/S3StateMachine.swift` |
| `38508e188d8efb022c2ec9082602e5358d9cd544` | `PhotoCleanupMVE/Core/S4StateMachine.swift` |
| `4683c137b912bc1b2bc01f0fd19238d0bf091059` | `PhotoCleanupMVE/Core/S5StateMachine.swift` |
| `101e9652206c225617f2d7734bcc6b76390e1497` | `PhotoCleanupMVE/Core/SessionPersistence.swift` |
| `17d36192898a3d584df37a7e3efaf9c088045789` | `PhotoCleanupMVE/Core/SessionStore.swift` |
| `8f307bca389563c9cb1815108ec1b739b8c6f782` | `PhotoCleanupMVE/Features/S3/S3View.swift` |
| `19572baf98e53bd49f347945562010a15ba68e51` | `PhotoCleanupMVE/Features/S4/S4View.swift` |
| `67186fc95740365ed29cb27863b3ed8472514a33` | `PhotoCleanupMVE/Features/S5/S5View.swift` |
| `1f9697f422d7772bde76ff4018092940d46bdfb2` | `PhotoCleanupMVE/Features/Shared/ThumbnailView.swift` |
| `d0f10158a061c12055a96cd9979403367b9fdeca` | `PhotoCleanupMVE/Services/AssetSizeScanner.swift` |
| `c537a658eaa61a277d1a460f891d352c7dfb4e3f` | `PhotoCleanupMVE/Services/FreeDiskSpaceReader.swift` |
| `aef458f0fa32f7083dfa787caaa8da9deb42feb6` | `PhotoCleanupMVE/Services/PhotoDeletionService.swift` |
| `0186402740366679914fe394e4c3c35ea2819eb0` | `PhotoCleanupMVE/Services/PhotoLibraryService.swift` |
| `0c2e813210eab2a87905bff048d56f07d84fc353` | `PhotoCleanupMVETests/CollectionInvariantTests.swift` |
| `85c967a04622078b105c2890de7d0f86fa4227bf` | `PhotoCleanupMVETests/CoverageGapTests.swift` |
| `091358b6a1d198b0fec4c3709db49694cef7b3ef` | `PhotoCleanupMVETests/S3StateMachineTests.swift` |
| `54740d5a74a9f958ac2534e188e1da763e7034a6` | `PhotoCleanupMVETests/S4StateMachineTests.swift` |
| `08916b1869dc920a02fda63543ae86a78a03d834` | `PhotoCleanupMVETests/S5StateMachineTests.swift` |
| `7bb23d64b61a5c4b962d182f45cb26732126f571` | `PhotoCleanupMVETests/SessionStoreTests.swift` |
| `e9067e8884602ae7a9b4e414e1a67e9f2b008bee` | `PhotoCleanupMVETests/SnapshotInvariantTests.swift` |
| `cf64501065d60d9bfc0edfb78acd0fd2e8a5ea60` | `PhotoCleanupMVETests/TransitionTableGuardTests.swift` |
| `d4c153c542f054f6895f7541661aefc1895673e2` | `PhotoCleanupMVETests/VolumeFormattingTests.swift` |

## 七、CI、XCTest、Release 与未签名 IPA

| 验收项 | 结果 |
|---|---|
| 受验提交 | `c9d54c959367cb9cd9c79758ef4bce319847f49c` |
| CI 运行 | `iOS 构建与自验 #21`，run ID `31801619923`，状态 `Success`；工作流总耗时 8 分 50 秒，唯一 job 耗时 8 分 46 秒 |
| CI 链接 | [GitHub Actions #21](https://github.com/a734462653-design/PhotoCleanupMVE/actions/runs/31801619923) |
| 通用结构自验 | 本地退出码 0；CI“运行通用结构自验”步骤通过，目录 72 项、产品源码引用 72 项、用户可见硬编码残留 0，并确认测试数量不少于 189 |
| CI 独立硬编码扫描 | “扫描用户可见硬编码字符串”步骤通过；目录与产品源码引用双向一致，残留为 0 |
| XCTest | CI 实际执行 203 项，203 项全部通过；测试总耗时 3.778 秒 |
| 失败 | 0 |
| unexpected | 0 |
| Release 构建 | 通过；CI 日志报告 `BUILD SUCCEEDED` |
| 未签名 `.app` 检查 | 通过；构建继续使用 `CODE_SIGNING_ALLOWED=NO`、`CODE_SIGNING_REQUIRED=NO` 与空 `CODE_SIGN_IDENTITY`，原有 `codesign`、`_CodeSignature`、`embedded.mobileprovision` 反向检查所在步骤成功 |
| 未签名 IPA 生成与完整性校验 | 通过；`PhotoCleanupMVE-unsigned.ipa` 为 242548 字节，`unzip -tq` 完整性校验成功，文件 SHA-256 为 `416dd2820ad7babc4942eb01f03b01724c831170a1363ea1b62a874eafbb4841` |
| IPA 上传 | 通过；产物名 `PhotoCleanupMVE-unsigned-c9d54c959367`，Artifact ID `9219722818`，上传归档 242718 字节，归档摘要 SHA-256 为 `87ecc405e538a7912ea88a4ad3b3fb62e8b5189b04b61ea66c3edf3c6b239faf` |

XCTest 日志同时给出总测试套件通过与 `TEST SUCCEEDED`；IPA 步骤给出压缩数据无错误，上传步骤确认产物完成固化。IPA 文件 SHA-256 与 GitHub 上传归档摘要是不同层级的两个摘要，均在上表分别记录。

## 八、范围与最终工作树

实现提交与 CI 证据回填后的最终范围复核结果如下。本报告回填提交使用 `[skip ci]`，只记录已经完成的 #21 结果，不改变受验提交：

- 任务基线到最终 HEAD 的差异路径严格为 `.github/workflows/ci.yml`、`Scripts/selfcheck.ps1`、`Reports/IC-20260814-044-SELF-VERIFICATION.md`。
- 7 个 `Scripts/verify-IC-20260812-*.ps1` 的路径集合和 Git blob 与任务基线一致。
- 26 个 Swift 源码与测试文件的路径集合和 Git blob 与任务基线一致。
- `Reports/IC-20260814-043-SELF-VERIFICATION.md` 及其他既有报告均未修改。
- SPEC、签名检查、未签名 IPA 校验与上传参数均未修改。
- 最终推送后，HEAD 与本地 `origin/main` 跟踪引用相同，工作树洁净，未跟踪条目为 0。

验收标准 1 至 7 全部满足。本卡在 044 完成处停止，没有回填或修改 043 报告。
